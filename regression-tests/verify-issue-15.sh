#!/usr/bin/env bash
# verify-issue-15 — verifies that the unreachable `git status --porcelain`
# regex check in regression-tests/verify-issue-1.sh has been cleaned up.
# issue-15 (fixing issue-1) regression protection script.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "FAIL: $1" >&2; exit 1; }

TARGET=regression-tests/verify-issue-1.sh
test -f "$TARGET" || fail "$TARGET missing"

# 1) Verify that the dead-code check itself has been removed — the 3-line block
#    that called `git status --porcelain` together with a regex must not remain
#    anywhere in verify-issue-1.sh.
if grep -q 'git status --porcelain' "$TARGET"; then
  fail "$TARGET still contains 'git status --porcelain' (dead-code check not removed)"
fi

# 2) The `test ! -f .env` guard on line 25 must be preserved.
grep -q '^test ! -f \.env' "$TARGET" \
  || fail "$TARGET is missing the '.env exists' guard (line 25 behavior)"

# 3) Baseline: verify-issue-1.sh must print OK in a clean state with no .env.
#    (This test assumes .env is absent in the user's environment, so abort if
#    .env already exists.)
test ! -f .env \
  || fail ".env already exists in repo root — refusing to run destructive cleanup. Remove it manually first."

bash "$TARGET" >/dev/null \
  || fail "$TARGET should pass OK when .env is absent"

# 4) Verify the line-25 guard is still active — temporarily create .env and
#    confirm verify-issue-1.sh reports a non-zero exit.
cleanup() { rm -f .env; }
trap cleanup EXIT
touch .env

set +e
bash "$TARGET" >/dev/null 2>&1
status=$?
set -e
test "$status" -ne 0 \
  || fail "$TARGET should have failed while .env existed (line 25 guard not effective)"
# Explicit reason message — the '.env should not exist' line must go to stderr.
# We temporarily turn off pipefail because bash's abnormal exit would
# otherwise fail the whole pipeline.
set +o pipefail
bash "$TARGET" 2>&1 | grep -q '\.env should not exist'
reason_rc=$?
set -o pipefail
test "$reason_rc" -eq 0 \
  || fail "$TARGET did not report the expected '.env should not exist' reason"

echo OK
