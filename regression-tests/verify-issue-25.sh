#!/usr/bin/env bash
# verify-issue-25 — verifies that engine/aimd/validators.py's extract_code
# does not leave the fence marker in the result for an unclosed fence (the
# case where only the opening fence remains due to LLM token-limit truncation).
# issue-25 (fixing issue-4 Finding 2) regression protection script.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "FAIL: $1" >&2; exit 1; }

TARGET=engine/aimd/validators.py
TESTS=engine/tests/test_validators.py

test -f "$TARGET" || fail "$TARGET missing"
test -f "$TESTS" || fail "$TESTS missing"

# 1) The unclosed-fence detection regex must be defined.
grep -q '^_UNCLOSED_FENCE_RE = re.compile' "$TARGET" \
  || fail "$TARGET is missing the _UNCLOSED_FENCE_RE fallback regex"

# 2) extract_code's body must fall back to the unclosed-fence pattern after
#    the closed-fence match fails.
if ! grep -A40 'def extract_code' "$TARGET" | grep -qE '_UNCLOSED_FENCE_RE\.search'; then
  fail "$TARGET extract_code does not fall back to _UNCLOSED_FENCE_RE.search"
fi

# 3) Regression tests must exist.
grep -q 'test_extract_code_unclosed_fence_strips_marker' "$TESTS" \
  || fail "$TESTS is missing the unclosed-fence marker-stripping test"
grep -q 'test_extract_code_unclosed_fence_no_language_tag' "$TESTS" \
  || fail "$TESTS is missing the unclosed-fence no-language-tag test"
grep -q 'test_extract_code_unclosed_4backtick_fence_strips_marker' "$TESTS" \
  || fail "$TESTS is missing the unclosed 4-backtick marker-stripping test"

# 4) Verify actual behavior — the marker must not remain in the result string.
cd engine
RESULT=$(uv run python -c "
from aimd.validators import extract_code
s = extract_code('hi\n\`\`\`python\nprint(1)')
assert s == 'print(1)', repr(s)
assert '\`\`\`' not in s
print('ok')
")
[ "$RESULT" = "ok" ] || fail "extract_code still leaves fence marker in unclosed-fence output"

# 5) All unit tests pass — direct evidence this change did not break existing
#    behavior.
uv run pytest tests/test_validators.py -q >/dev/null \
  || fail "engine/tests/test_validators.py failed after unclosed-fence handling"
cd ..

echo OK
