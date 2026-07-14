#!/usr/bin/env bash
# verify-issue-16 — verifies that README.md's temporary-exposure ngrok command
# is written using the v3 standard (space-separated) syntax.
# issue-16 (fixing issue-1) regression protection script.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "FAIL: $1" >&2; exit 1; }

TARGET=README.md
test -f "$TARGET" || fail "$TARGET missing"

# 1) Verify the v3 standard syntax (space-separated) appears at least once.
grep -qF 'ngrok http --basic-auth "user:pass" 8080' "$TARGET" \
  || fail "$TARGET is missing the ngrok v3 syntax 'ngrok http --basic-auth \"user:pass\" 8080'"

# 2) Verify no v2-style (=-joined) syntax remains. The `--basic-auth="..."` or
#    `--basic-auth=...` form must never appear.
if grep -nE '\-\-basic-auth=' "$TARGET"; then
  fail "$TARGET still contains v2-style '--basic-auth=...' (ngrok v3 uses space-separated form)"
fi

# 3) Verify the other parts of the warning paragraph (bold formatting, the
#    LLM-runs-generated-code warning) have been preserved.
grep -q '\*\*이 시스템은 LLM이 생성한 코드를 그대로 실행합니다' "$TARGET" \
  || fail "$TARGET lost the LLM-runs-generated-code warning sentence"
grep -q '공인 인터넷에 상시 노출하지 마세요' "$TARGET" \
  || fail "$TARGET lost the 'do not expose to public internet' phrasing"
grep -q '일시 공개는' "$TARGET" \
  || fail "$TARGET lost the 'temporary exposure' phrasing"

echo OK