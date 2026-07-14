import logging
import os
import tempfile
import threading
from collections import defaultdict
from pathlib import Path

from . import artifacts, classifier, llm, validators
from .classifier import Target
from .config import Settings
from .prompts import API_SYSTEM, FIX_TEMPLATE, SPA_SYSTEM

log = logging.getLogger("aimd.compiler")

_locks: dict[str, threading.Lock] = defaultdict(threading.Lock)
_locks_guard = threading.Lock()


class CompileError(Exception):
    """Final failure even after validation. Guarantees the existing cache was left untouched."""


def _get_lock(name: str) -> threading.Lock:
    with _locks_guard:
        return _locks[name]


def _import_gate(code: str) -> str | None:
    """Stage-2 validation for the api target only. Writes to a tmp .py file and
    checks via load_module that the actual import succeeds. Returns None if OK,
    else an English error message."""
    fd, tmp_name = tempfile.mkstemp(suffix=".py")
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(code)
        validators.load_module(tmp_path)
    except (Exception, SystemExit) as e:
        # issue-44: if the LLM-generated code calls sys.exit(...) at the top
        # level, a SystemExit (subclass of BaseException, not Exception) is
        # raised. Missing this would terminate the calling thread/process
        # outright with no retry.
        return f"{type(e).__name__}: {e}"
    finally:
        tmp_path.unlink(missing_ok=True)
    return None


def _validate(target: Target, code: str) -> str | None:
    """Per-target validation. For api, passing the syntax check alone isn't
    enough -- the actual import must also succeed for validation to pass
    (ADR-0008 two-stage validation)."""
    if target == "spa":
        return validators.validate_html(code)
    error = validators.validate_python(code)
    if error is not None:
        return error
    return _import_gate(code)


def compile_spec(name: str, settings: Settings) -> Path:
    """Compiles name (e.g. "convert.ai.md") and returns the artifact path."""
    with _get_lock(name):
        if not artifacts.is_stale(name, settings):
            existing = artifacts.artifact_path(name, settings)
            if existing is not None:
                return existing

        spec_file = artifacts.spec_path(name, settings)
        if not spec_file.exists():
            raise FileNotFoundError(f"spec not found: {spec_file}")

        spec_text = spec_file.read_text(encoding="utf-8")
        target = classifier.classify(spec_text, settings)
        system = SPA_SYSTEM if target == "spa" else API_SYSTEM

        raw = llm.chat(system, spec_text, settings)
        code = validators.extract_code(raw)
        error = _validate(target, code)

        if error is not None:
            raw2 = llm.chat(
                system,
                spec_text + "\n\n" + FIX_TEMPLATE.format(error=error),
                settings,
            )
            code = validators.extract_code(raw2)
            error = _validate(target, code)
            if error is not None:
                log.error("compile failed for %s: %s", name, error)
                raise CompileError(error)

        if target == "spa":
            stale_artifact = artifacts.py_path(name, settings)
            out = artifacts.html_path(name, settings)
        else:
            stale_artifact = artifacts.html_path(name, settings)
            out = artifacts.py_path(name, settings)

        # issue-43: deletion of the opposite-extension artifact only happens
        # "after" the new artifact write has succeeded. If atomic_write fails
        # first (e.g. disk full), the exception must propagate without touching
        # the existing cache (ADR-0008 availability guarantee).
        artifacts.atomic_write(out, code)
        if stale_artifact.exists():
            stale_artifact.unlink()
        return out
