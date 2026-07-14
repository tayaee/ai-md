#!/usr/bin/env bash
# issue-43: compile_spec — only delete the opposite-extension artifact after atomic_write succeeds (regression verification)
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== 1. compiler.py — atomic_write is called before stale_artifact.unlink ==="
# Check the relative order of the two lines with grep -n: atomic_write line number < unlink line number
ATOMIC_LINE=$(grep -n 'artifacts.atomic_write(out, code)' engine/aimd/compiler.py | head -1 | cut -d: -f1)
UNLINK_LINE=$(grep -n 'stale_artifact.unlink()' engine/aimd/compiler.py | head -1 | cut -d: -f1)
if [ -z "$ATOMIC_LINE" ] || [ -z "$UNLINK_LINE" ]; then
  echo "FAIL: could not find the atomic_write or unlink call" >&2
  exit 1
fi
if [ "$ATOMIC_LINE" -ge "$UNLINK_LINE" ]; then
  echo "FAIL: stale_artifact.unlink() runs before atomic_write (line $UNLINK_LINE <= $ATOMIC_LINE) — risk of cache loss" >&2
  exit 1
fi

echo "=== 2. Regression test exists ==="
grep -q 'test_compile_spec_preserves_stale_opposite_artifact_when_atomic_write_fails' engine/tests/test_compiler.py

echo "=== 3. Unit tests ==="
cd engine && uv run python -m pytest tests/test_compiler.py -q
cd ..

echo "OK: issue-43 regression verification passed"
