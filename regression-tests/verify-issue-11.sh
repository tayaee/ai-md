#!/usr/bin/env bash
# issue-11: watcher.py — watchdog precompile thread regression verification
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== 1. watcher.py exists + core signatures ==="
test -f engine/aimd/watcher.py
grep -q 'class _SpecEventHandler' engine/aimd/watcher.py
grep -q 'def start_watcher' engine/aimd/watcher.py

echo "=== 2. test_watcher.py exists ==="
test -f engine/tests/test_watcher.py

echo "=== 3. Verify integration with main.py ==="
grep -q 'self.watcher = start_watcher' engine/aimd/main.py

echo "=== 4. Unit tests ==="
cd engine && uv run python -m pytest tests/test_watcher.py -q
cd ..

echo "OK: issue-11 regression verification passed"
