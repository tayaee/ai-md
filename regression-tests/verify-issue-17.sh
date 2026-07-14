#!/usr/bin/env bash
# verify-issue-17 — verifies that the "difference from plan" wording in
# issues/archive/2026/07/12/issue-1.md explicitly acknowledges the existence
# of the 11th file (the regression script).
# issue-17 (fixing issue-1) regression protection script.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "FAIL: $1" >&2; exit 1; }

TARGET=issues/archive/2026/07/12/issue-1.md
test -f "$TARGET" || fail "$TARGET missing"

# 1) The changed-files list (around line 99) must explicitly list the 11th
#    file, the regression script.
grep -q 'regression-tests/verify-issue-1\.sh' "$TARGET" \
  || fail "$TARGET does not list regression-tests/verify-issue-1.sh among the changed files"

# 2) The "difference from plan" section line must still exist as-is.
grep -q '\*\*계획과의 차이\*\*:' "$TARGET" \
  || fail "$TARGET lost the '**계획과의 차이**' line"

# 3) New wording must be added acknowledging the regression script as a
#    "required procedural deliverable".
grep -q '절차상 필수 산출물' "$TARGET" \
  || fail "$TARGET '계획과의 차이' wording does not acknowledge the regression script"

# 4) Verify the report's self-contradiction is gone — that the "10 files"
#    assertion and the existence of the 11th file are reconcilable in context
#    (the regression-script mention must be inside the "procedural" paragraph).
if ! grep -A2 '절차상 필수 산출물' "$TARGET" | grep -q 'regression-tests/verify-issue-1\.sh'; then
  fail "$TARGET — the '절차상 필수 산출물' phrase does not reference the regression script"
fi

echo OK