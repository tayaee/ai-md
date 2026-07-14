#!/usr/bin/env bash
# issue-9: registry.py — dynamic sub-app registry regression verification
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== 1. registry.py exists + core signatures ==="
test -f engine/aimd/registry.py
grep -q '^class AppRegistry' engine/aimd/registry.py
grep -q 'def get' engine/aimd/registry.py
grep -q 'def drop' engine/aimd/registry.py

echo "=== 2. test_registry.py exists ==="
test -f engine/tests/test_registry.py

echo "=== 3. Uses per-name locking (issue-50) ==="
grep -q '_lock_for' engine/aimd/registry.py

echo "=== 4. Unit tests ==="
cd engine && uv run python -m pytest tests/test_registry.py -q
cd ..

echo "OK: issue-9 regression verification passed"
