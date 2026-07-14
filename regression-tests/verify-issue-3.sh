#!/bin/bash
set -e

# 1. Check that the files exist
if [ ! -f "engine/aimd/artifacts.py" ]; then
    echo "engine/aimd/artifacts.py does not exist"
    exit 1
fi

if [ ! -f "engine/tests/test_artifacts.py" ]; then
    echo "engine/tests/test_artifacts.py does not exist"
    exit 1
fi

# 2. Check required definitions
grep -q "def spec_path" "engine/aimd/artifacts.py" || (echo "spec_path function missing"; exit 1)
grep -q "def html_path" "engine/aimd/artifacts.py" || (echo "html_path function missing"; exit 1)
grep -q "def py_path" "engine/aimd/artifacts.py" || (echo "py_path function missing"; exit 1)
grep -q "def artifact_path" "engine/aimd/artifacts.py" || (echo "artifact_path function missing"; exit 1)
grep -q "def is_stale" "engine/aimd/artifacts.py" || (echo "is_stale function missing"; exit 1)
grep -q "def atomic_write" "engine/aimd/artifacts.py" || (echo "atomic_write function missing"; exit 1)
grep -q "def list_specs" "engine/aimd/artifacts.py" || (echo "list_specs function missing"; exit 1)

# 3. Run tests
cd engine
uv run pytest tests/test_artifacts.py -q
