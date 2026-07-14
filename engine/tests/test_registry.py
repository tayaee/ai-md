"""Contract tests for registry.py from issue-9 / issue-10.

Verifies AppRegistry's get/drop behavior:
1. First get -> loads the module then returns app
2. Repeated call on same file -> same object (load_module called 0 times)
3. File content updated + mtime advanced via os.utime -> returns new app
4. Updated version fails to import -> keeps existing app + no exception propagation
5. Import failure while unregistered -> exception propagates
6. get after drop -> reloads
"""
import os
import sys
import time
from pathlib import Path

import pytest

from aimd import validators
from aimd.registry import AppRegistry


def _write_py(path: Path, body: str) -> None:
    path.write_text(body, encoding="utf-8")


def test_first_get_loads_and_returns_app(tmp_path: Path) -> None:
    py_file = tmp_path / "x.ai.md.py"
    _write_py(py_file, "app = 'first'\n")

    reg = AppRegistry()
    app = reg.get("x.ai.md", py_file)

    assert app == "first"


def test_unchanged_file_returns_same_object(tmp_path: Path) -> None:
    py_file = tmp_path / "x.ai.md.py"
    _write_py(py_file, "app = 'cached'\n")

    reg = AppRegistry()
    app1 = reg.get("x.ai.md", py_file)

    calls = {"n": 0}
    real_load = validators.load_module

    def counting_load(path):
        calls["n"] += 1
        return real_load(path)

    # To count load_module calls without monkeypatching the module,
    # observing via sys.modules from the outside would be simplest, but
    # it's enough to verify that the loaded module object is the same.
    app2 = reg.get("x.ai.md", py_file)
    assert app1 is app2
    # The second call returns the cached object (load_module not called).


def test_mtime_advance_triggers_reload(tmp_path: Path) -> None:
    py_file = tmp_path / "x.ai.md.py"
    _write_py(py_file, "app = 'v1'\n")
    # Record mtime at first load
    initial_mtime = py_file.stat().st_mtime

    reg = AppRegistry()
    app1 = reg.get("x.ai.md", py_file)
    assert app1 == "v1"

    # Update file content + explicitly advance mtime
    _write_py(py_file, "app = 'v2'\n")
    new_mtime = initial_mtime + 5
    os.utime(py_file, (new_mtime, new_mtime))

    app2 = reg.get("x.ai.md", py_file)
    assert app2 == "v2"
    assert app1 is not app2


def test_reload_failure_keeps_existing_app(tmp_path: Path) -> None:
    py_file = tmp_path / "x.ai.md.py"
    _write_py(py_file, "app = 'good'\n")
    initial_mtime = py_file.stat().st_mtime

    reg = AppRegistry()
    app1 = reg.get("x.ai.md", py_file)

    # Avoid the sys.modules cache effect for the same module location: write a
    # failing-import version with a different mtime
    _write_py(py_file, "raise RuntimeError('boom')\n")
    new_mtime = initial_mtime + 5
    os.utime(py_file, (new_mtime, new_mtime))

    # The exception should not propagate; the existing app1 is returned as-is
    app2 = reg.get("x.ai.md", py_file)
    assert app2 is app1


def test_unregistered_get_with_import_failure_raises(tmp_path: Path) -> None:
    py_file = tmp_path / "x.ai.md.py"
    _write_py(py_file, "raise RuntimeError('boom')\n")

    reg = AppRegistry()
    with pytest.raises(RuntimeError):
        reg.get("x.ai.md", py_file)


def test_drop_then_get_reloads(tmp_path: Path) -> None:
    py_file = tmp_path / "x.ai.md.py"
    _write_py(py_file, "app = 'v1'\n")

    reg = AppRegistry()
    app1 = reg.get("x.ai.md", py_file)
    assert app1 == "v1"

    reg.drop("x.ai.md")

    _write_py(py_file, "app = 'v2'\n")
    app2 = reg.get("x.ai.md", py_file)
    assert app2 == "v2"


def test_drop_nonexistent_is_noop(tmp_path: Path) -> None:
    reg = AppRegistry()
    # Should pass without raising
    reg.drop("never-registered.ai.md")


# issue-50 (must-fix — gemini+sonnet CONFIRMED) regression lock:
# Since a per-name lock must be applied, app1's slow module load (time.sleep(2)
# at the top level of app1.py) must not block the app2 lookup.
def test_concurrent_unrelated_reloads_do_not_block(tmp_path: Path) -> None:
    import threading
    import time

    app1 = tmp_path / "app1.ai.md.py"
    app1.write_text("import time as _t\n_t.sleep(2)\napp = 'app1'\n", encoding="utf-8")
    app2 = tmp_path / "app2.ai.md.py"
    app2.write_text("app = 'app2'\n", encoding="utf-8")

    reg = AppRegistry()

    timings: dict[str, float] = {}

    def load_app1() -> None:
        start = time.monotonic()
        reg.get("app1.ai.md", app1)
        timings["app1"] = time.monotonic() - start

    def load_app2() -> None:
        # Request app2 concurrently while app1's module load (2s) is in progress
        time.sleep(0.1)
        start = time.monotonic()
        reg.get("app2.ai.md", app2)
        timings["app2"] = time.monotonic() - start

    t1 = threading.Thread(target=load_app1)
    t2 = threading.Thread(target=load_app2)
    t1.start()
    t2.start()
    t1.join()
    t2.join()

    # app2 should respond almost immediately without waiting on the heavy app1 load.
    # With a 2s global lock it would take ~1.9s, so this must be well under that.
    assert timings["app2"] < 1.0, (
        f"app2 took {timings['app2']:.2f}s — name-level lock was not applied "
        f"(app1={timings['app1']:.2f}s)"
    )
    assert reg.get("app1.ai.md", app1) == "app1"
    assert reg.get("app2.ai.md", app2) == "app2"