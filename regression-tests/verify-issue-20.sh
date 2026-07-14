#!/usr/bin/env bash
# verify-issue-20 — verifies that engine/aimd/artifacts.py's atomic_write
# auto-creates the parent directory when it's missing and works correctly.
# issue-20 (fixing issue-3) regression protection script.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "FAIL: $1" >&2; exit 1; }

TARGET=engine/aimd/artifacts.py
test -f "$TARGET" || fail "$TARGET missing"

# 1) atomic_write's body must have a mkdir(parents=True, exist_ok=True) guard.
#    Exactly the fix pattern the issue body specifies. The body has a long
#    docstring, so we look at a 15-line context window.
if ! grep -A15 'def atomic_write' "$TARGET" | grep -qE 'mkdir\(parents=True,\s*exist_ok=True\)'; then
  fail "$TARGET atomic_write is missing the 'mkdir(parents=True, exist_ok=True)' parent-dir guard"
fi

# 2) The atomic-write core mechanism must be preserved — mkstemp + os.replace
#    + tmp unlink on failure.
grep -q 'tempfile.mkstemp' "$TARGET" \
  || fail "$TARGET atomic_write lost the tempfile.mkstemp atomic-write core"
grep -q 'os.replace' "$TARGET" \
  || fail "$TARGET atomic_write lost the os.replace atomic-rename step"
grep -q 'os.unlink(tmp_path)' "$TARGET" \
  || fail "$TARGET atomic_write lost the tmp-cleanup-on-failure step"

# 3) Verify all artifacts unit tests pass — direct evidence this change did
#    not break existing behavior.
cd engine
uv run pytest tests/test_artifacts.py -q >/dev/null \
  || fail "engine/tests/test_artifacts.py failed after atomic_write change"
cd ..

echo OK