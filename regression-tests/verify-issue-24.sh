#!/usr/bin/env bash
# verify-issue-24 — verifies that engine/aimd/validators.py's extract_code
# recognizes 4-backtick fences first, correctly handling markdown-example
# patterns embedded in docstrings. issue-24 (fixing issue-4) regression
# protection script.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "FAIL: $1" >&2; exit 1; }

TARGET=engine/aimd/validators.py
TESTS=engine/tests/test_validators.py

test -f "$TARGET" || fail "$TARGET missing"
test -f "$TESTS" || fail "$TESTS missing"

# 1) The _4FENCE_RE regex must be defined (4-backtick priority handling).
grep -q '^_4FENCE_RE = re.compile' "$TARGET" \
  || fail "$TARGET is missing the _4FENCE_RE 4-backtick regex"

# 2) extract_code's body must attempt 4-backtick matching first.
# (issue-25 added unclosed-fence policy notes to the docstring, shifting the
#  actual call sites' line numbers — so instead of a fixed -A20 window, we
#  judge by the order in which the two findall calls appear.)
FIND4_LINE=$(grep -n '_4FENCE_RE\.findall' "$TARGET" | head -1 | cut -d: -f1)
FIND3_LINE=$(grep -n '_FENCE_RE\.findall' "$TARGET" | grep -v '_4FENCE_RE' | head -1 | cut -d: -f1)
if [ -z "$FIND4_LINE" ] || [ -z "$FIND3_LINE" ] || [ "$FIND4_LINE" -ge "$FIND3_LINE" ]; then
  fail "$TARGET extract_code does not call _4FENCE_RE.findall before _FENCE_RE"
fi

# 3) A regression test for the fence-inside-docstring case must exist.
grep -q 'test_extract_code_picks_4backtick_over_3backtick' "$TESTS" \
  || fail "$TESTS is missing the 4-backtick-priority test"
grep -q 'test_extract_code_4backtick_is_the_only_fence' "$TESTS" \
  || fail "$TESTS is missing the 4-backtick-only test"

# 4) Fence indentation must be allowed — both patterns must have the ^[ \t]* guard.
if ! grep -q '_FENCE_RE = re.compile' "$TARGET" || \
   ! grep -q 're.MULTILINE' "$TARGET" || \
   ! grep -qE '\^\[ \\t\]\*' "$TARGET"; then
  fail "$TARGET fence regexes are missing the ^[ \t]* indent allowance + MULTILINE flag"
fi

# 5) Verify all unit tests pass — direct evidence this change did not break
#    existing behavior.
cd engine
uv run pytest tests/test_validators.py -q >/dev/null \
  || fail "engine/tests/test_validators.py failed after 4-backtick priority addition"
cd ..

echo OK