#!/usr/bin/env bash
# verify-issue-18 — verifies that verify-issue-1.sh checks README.md's 5 spec
# elements (title, one-line intro + security warning + bold formatting,
# docs/SPEC.md link, docs/adr link) with individual grep checks.
# issue-18 (fixing issue-1) regression protection script.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "FAIL: $1" >&2; exit 1; }

TARGET=regression-tests/verify-issue-1.sh
test -f "$TARGET" || fail "$TARGET missing"

# 1) Verify that grep checks for all 5 spec elements exist in verify-issue-1.sh.
#    The core of this issue is that the old weak one-liner check
#    ("grep -q 'AIMD' ...") was split into 5 concrete checks.
grep -q "^grep -q '\^# AIMD — AI-powered Markdown Engine' README.md" "$TARGET" \
  || fail "$TARGET is missing the README title grep (spec element 1)"
grep -q "grep -q 'LLM이 생성한 코드를 그대로 실행' README.md" "$TARGET" \
  || fail "$TARGET is missing the security-warning grep (spec element 2)"
grep -qE 'grep -qE .\\*\\*.*ngrok http --basic-auth' "$TARGET" \
  || fail "$TARGET is missing the bolded-ngrok grep (spec element 3)"
grep -q "grep -q 'docs/SPEC.md' README.md" "$TARGET" \
  || fail "$TARGET is missing the SPEC.md link grep (spec element 4)"
grep -q "grep -q 'docs/adr' README.md" "$TARGET" \
  || fail "$TARGET is missing the adr link grep (spec element 5)"

# 2) Verify the old weak check (`grep -q 'AIMD' README.md`) no longer performs
#    README validation on its own — i.e. that the 5-element grep is now the
#    real guard. It's fine if the pattern exists on its own line alongside
#    other greps; it must not be a standalone line starting with
#    `grep -q 'AIMD' README.md` (which would mean it regressed to the old
#    single weak check).
if grep -nE "^grep -q 'AIMD' README.md" "$TARGET" >/dev/null; then
  fail "$TARGET still has the weak single 'grep -q AIMD README.md' check on its own line"
fi

# 3) Verify verify-issue-1.sh passes with OK against a normal README.md.
README=README.md
test -f "$README" || fail "$README missing"
bash "$TARGET" >/dev/null \
  || fail "$TARGET failed on the current clean README.md (it should OK)"

echo OK