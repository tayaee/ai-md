import os
import time
from pathlib import Path

import pytest
from aimd import compiler
from aimd.compiler import CompileError
from aimd.config import Settings

VALID_HTML = "<!DOCTYPE html><html><head></head><body>hi</body></html>"
# Since extract_code strips the trailing newline (the no-fence path uses .strip()),
# the final saved code has no trailing newline even if the LLM returns code with one.
VALID_API_RAW = "app = object()\n"
VALID_API = "app = object()"
BROKEN_API = "def broken(:\n"


@pytest.fixture
def test_settings(tmp_path: Path) -> Settings:
    src_dir = tmp_path / "src"
    dist_dir = tmp_path / "dist"
    src_dir.mkdir()
    dist_dir.mkdir()
    return Settings(
        api_key="dummy_key",
        base_url="https://api.minimax.io/v1",
        model="MiniMax-M3",
        max_tokens=200000,
        src_dir=src_dir,
        dist_dir=dist_dir,
    )


def write_spec(settings: Settings, name: str, text: str) -> Path:
    path = settings.src_dir / name
    path.write_text(text, encoding="utf-8")
    return path


def test_compile_spec_spa_success(monkeypatch, test_settings):
    name = "index.ai.md"
    write_spec(test_settings, name, "landing page spec")
    monkeypatch.setattr(compiler.classifier, "classify", lambda text, s: "spa")
    monkeypatch.setattr(compiler.llm, "chat", lambda sys, user, s: VALID_HTML)

    out = compiler.compile_spec(name, test_settings)

    assert out == test_settings.dist_dir / (name + ".html")
    assert out.read_text(encoding="utf-8") == VALID_HTML


def test_compile_spec_api_success(monkeypatch, test_settings):
    name = "convert.ai.md"
    write_spec(test_settings, name, "api spec")
    monkeypatch.setattr(compiler.classifier, "classify", lambda text, s: "api")
    monkeypatch.setattr(compiler.llm, "chat", lambda sys, user, s: VALID_API_RAW)

    out = compiler.compile_spec(name, test_settings)

    assert out == test_settings.dist_dir / (name + ".py")
    assert out.read_text(encoding="utf-8") == VALID_API


def test_compile_spec_fix_retry_succeeds_on_second_try(monkeypatch, test_settings):
    name = "convert.ai.md"
    write_spec(test_settings, name, "api spec")
    monkeypatch.setattr(compiler.classifier, "classify", lambda text, s: "api")

    calls = []

    def fake_chat(system, user, s):
        calls.append(user)
        return BROKEN_API if len(calls) == 1 else VALID_API_RAW

    monkeypatch.setattr(compiler.llm, "chat", fake_chat)

    out = compiler.compile_spec(name, test_settings)

    assert len(calls) == 2
    assert out.read_text(encoding="utf-8") == VALID_API


def test_compile_spec_fails_after_two_tries_raises_compile_error(monkeypatch, test_settings):
    name = "convert.ai.md"
    write_spec(test_settings, name, "api spec")
    monkeypatch.setattr(compiler.classifier, "classify", lambda text, s: "api")

    calls = []

    def fake_chat(system, user, s):
        calls.append(user)
        return BROKEN_API

    monkeypatch.setattr(compiler.llm, "chat", fake_chat)

    with pytest.raises(CompileError):
        compiler.compile_spec(name, test_settings)

    assert len(calls) == 2
    assert not (test_settings.dist_dir / (name + ".py")).exists()


def test_compile_spec_preserves_existing_artifact_on_failure(monkeypatch, test_settings):
    name = "convert.ai.md"
    spec_path = write_spec(test_settings, name, "api spec")
    out_path = test_settings.dist_dir / (name + ".py")
    out_path.write_text("OLD VERSION", encoding="utf-8")

    now = time.time()
    os.utime(out_path, (now, now))
    os.utime(spec_path, (now + 10, now + 10))  # spec is newer -> stale

    monkeypatch.setattr(compiler.classifier, "classify", lambda text, s: "api")
    monkeypatch.setattr(compiler.llm, "chat", lambda sys, user, s: BROKEN_API)

    with pytest.raises(CompileError):
        compiler.compile_spec(name, test_settings)

    assert out_path.read_text(encoding="utf-8") == "OLD VERSION"


def test_compile_spec_returns_cached_artifact_without_calling_llm(monkeypatch, test_settings):
    name = "convert.ai.md"
    spec_path = write_spec(test_settings, name, "api spec")
    out_path = test_settings.dist_dir / (name + ".py")
    out_path.write_text("CACHED", encoding="utf-8")

    now = time.time()
    os.utime(spec_path, (now, now))
    os.utime(out_path, (now + 10, now + 10))  # artifact is newer -> not stale

    def boom(*args, **kwargs):
        raise AssertionError("should not be called when cache is fresh")

    monkeypatch.setattr(compiler.llm, "chat", boom)
    monkeypatch.setattr(compiler.classifier, "classify", boom)

    out = compiler.compile_spec(name, test_settings)

    assert out == out_path
    assert out.read_text(encoding="utf-8") == "CACHED"


def test_compile_spec_missing_spec_raises_file_not_found(test_settings):
    with pytest.raises(FileNotFoundError):
        compiler.compile_spec("missing.ai.md", test_settings)


def test_compile_spec_deletes_opposite_extension_artifact(monkeypatch, test_settings):
    """When the classification changes (previously only a spa artifact existed, now
    classified as api), the existing opposite-extension artifact must be deleted."""
    name = "convert.ai.md"
    spec_path = write_spec(test_settings, name, "api spec")
    old_html = test_settings.dist_dir / (name + ".html")
    old_html.write_text("<html>old</html>", encoding="utf-8")

    now = time.time()
    os.utime(old_html, (now, now))
    os.utime(spec_path, (now + 10, now + 10))  # spec is newer -> stale

    monkeypatch.setattr(compiler.classifier, "classify", lambda text, s: "api")
    monkeypatch.setattr(compiler.llm, "chat", lambda sys, user, s: VALID_API)

    out = compiler.compile_spec(name, test_settings)

    assert out == test_settings.dist_dir / (name + ".py")
    assert not old_html.exists()


def test_compile_spec_preserves_stale_opposite_artifact_when_atomic_write_fails(
    monkeypatch, test_settings
):
    """issue-43: if atomic_write fails (validation passed but the write itself
    failed), the existing opposite-extension artifact must not be deleted
    beforehand — doing so would cause a complete cache loss with no artifact
    left in dist (violating ADR-0008 "failure must not compromise availability")."""
    name = "convert.ai.md"
    spec_path = write_spec(test_settings, name, "api spec")
    old_html = test_settings.dist_dir / (name + ".html")
    old_html.write_text("<html>old</html>", encoding="utf-8")

    now = time.time()
    os.utime(old_html, (now, now))
    os.utime(spec_path, (now + 10, now + 10))  # spec is newer -> stale

    monkeypatch.setattr(compiler.classifier, "classify", lambda text, s: "api")
    monkeypatch.setattr(compiler.llm, "chat", lambda sys, user, s: VALID_API_RAW)

    def boom(path, text):
        raise OSError("disk full (simulated)")

    monkeypatch.setattr(compiler.artifacts, "atomic_write", boom)

    with pytest.raises(OSError):
        compiler.compile_spec(name, test_settings)

    # Validation passed but the actual write failed — the existing opposite-
    # extension artifact must remain untouched (prevents complete cache loss).
    assert old_html.exists()
    assert old_html.read_text(encoding="utf-8") == "<html>old</html>"
    assert not (test_settings.dist_dir / (name + ".py")).exists()


def test_compile_spec_system_exit_from_llm_code_does_not_crash_process(
    monkeypatch, test_settings
):
    """issue-44: even if the LLM-generated code raises SystemExit (a
    BaseException), compile_spec must treat it as a validation failure, retry
    the fix once, then convert it into a CompileError — SystemExit must not
    propagate out to the caller and kill the process/thread."""
    name = "convert.ai.md"
    write_spec(test_settings, name, "api spec")
    monkeypatch.setattr(compiler.classifier, "classify", lambda text, s: "api")

    calls = []

    def fake_chat(system, user, s):
        calls.append(user)
        return "import sys\nsys.exit(99)\napp = object()"

    monkeypatch.setattr(compiler.llm, "chat", fake_chat)

    with pytest.raises(CompileError):
        compiler.compile_spec(name, test_settings)

    # The single fix retry must be exhausted normally (must not exit early
    # because it was blocked by SystemExit).
    assert len(calls) == 2
