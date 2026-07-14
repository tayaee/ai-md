import time
from pathlib import Path
import pytest

from aimd import compiler
from aimd.config import Settings
from aimd.watcher import start_watcher


def test_watcher_precompilation(tmp_path: Path) -> None:
    src_dir = tmp_path / "src"
    src_dir.mkdir()
    dist_dir = tmp_path / "dist"
    dist_dir.mkdir()

    settings = Settings(
        api_key="dummy",
        base_url="dummy_url",
        model="dummy_model",
        max_tokens=1000,
        src_dir=src_dir,
        dist_dir=dist_dir,
    )

    compiled_names = []

    def mock_compile_spec(name, settings_obj):
        compiled_names.append(name)

    # Mock compiler.compile_spec
    original_compile_spec = compiler.compile_spec
    compiler.compile_spec = mock_compile_spec

    observer = None
    try:
        observer = start_watcher(settings)

        # 1. Test detection of *.ai.md file creation
        ai_md_file = src_dir / "test.ai.md"
        ai_md_file.write_text("spec content")

        # Wait for watchdog to process the event
        time.sleep(1.5)
        assert "test.ai.md" in compiled_names
        compiled_names.clear()

        # 2. Test that *.txt file creation is ignored
        txt_file = src_dir / "test.txt"
        txt_file.write_text("txt content")

        time.sleep(1.5)
        assert "test.txt" not in compiled_names

        # 3. Debounce test (two rapid consecutive saves)
        ai_md_file.write_text("spec update 1")
        ai_md_file.write_text("spec update 2")

        time.sleep(1.5)
        # Since the saves happened within 0.5s of each other, it should be called only once
        assert len(compiled_names) == 1
        assert compiled_names[0] == "test.ai.md"

    finally:
        if observer is not None:
            observer.stop()
            observer.join()
        compiler.compile_spec = original_compile_spec
