#!/usr/bin/env bash
# verify-issue-53.sh — mechanical checks for issue-53 (nested .ai.md directories).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. _AIMD_RE must allow directory segments before the final .ai.md name
grep -qE '_AIMD_RE = re\.compile\(r"\^/\(\(\?:\[\^/\]\+/\)\*\[\^/\]\+\\\.ai\\\.md\)' \
    engine/aimd/main.py || fail "main.py _AIMD_RE does not allow nested directories"

# 2. list_specs must recurse (rglob) instead of a flat iterdir scan
grep -q 'rglob("\*.ai.md")' engine/aimd/artifacts.py \
    || fail "artifacts.list_specs does not recurse into subdirectories"

# 3. new nested-routing tests exist
grep -q "def test_nested_dir_spa_served" engine/tests/test_main.py \
    || fail "test_main.py missing test_nested_dir_spa_served"
grep -q "def test_nested_dir_py_subapp_receives_correct_scope" engine/tests/test_main.py \
    || fail "test_main.py missing test_nested_dir_py_subapp_receives_correct_scope"

# 4. targeted unit tests actually pass
if [ -f engine/.venv/Scripts/python.exe ]; then
    PYTHON=engine/.venv/Scripts/python.exe
elif [ -f engine/.venv/bin/python ]; then
    PYTHON=engine/.venv/bin/python
else
    PYTHON=python3
fi
PYTHONPATH=engine "$PYTHON" -m pytest -q engine -k "nested or list_specs" \
    || fail "issue-53 targeted tests did not pass"

echo OK
