#!/usr/bin/env bash
# verify-issue-23 — verifies that engine/aimd/validators.py's extract_code
# explicitly documents its trailing-newline policy, and that the behavior is
# locked in by pytest. issue-23 (fixing issue-4) regression protection script.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "FAIL: $1" >&2; exit 1; }

TARGET=engine/aimd/validators.py
SPEC=issues/archive/2026/07/12/issue-4.md
TESTS=engine/tests/test_validators.py

test -f "$TARGET" || fail "$TARGET missing"
test -f "$SPEC"   || fail "$SPEC missing"
test -f "$TESTS"  || fail "$TESTS missing"

# 1) extract_code's body must explicitly state the trailing-newline policy
#    (issue-23's fix).
if ! grep -A20 'def extract_code' "$TARGET" | grep -qE 'trailing.newline'; then
  fail "$TARGET extract_code docstring is missing the trailing-newline policy line"
fi

# 2) The same policy must also be reflected in the issue-4 archived spec.
if ! grep -A8 'def extract_code' "$SPEC" | grep -qE 'trailing.newline'; then
  fail "$SPEC extract_code spec is missing the trailing-newline policy line"
fi

# 3) Regression test — the policy of stripping all trailing newlines must be
#    locked in.
grep -q 'test_extract_code_strips_all_trailing_newlines' "$TESTS" \
  || fail "$TESTS is missing the 'strips_all_trailing_newlines' locking test"

# 4) Verify all unit tests pass — direct evidence this change did not break
#    existing behavior.
cd engine
uv run pytest tests/test_validators.py -q >/dev/null \
  || fail "engine/tests/test_validators.py failed after extract_code docstring/policy test addition"
cd ..

echo OK