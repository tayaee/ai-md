#!/usr/bin/env bash
# verify-issue-10.sh — verifies the acceptance criteria for issue-10 (ASGI dispatcher + AppRegistry).
# Mechanical checks (only this issue's acceptance criteria):
#   1. engine/aimd/main.py exists and exposes AIMDDispatcher/helpers/create_app
#   2. engine/aimd/registry.py exists and exposes AppRegistry/drop
#   3. engine/tests/test_main.py / test_registry.py exist
#   4. main.py imports AppRegistry and calls get(name, py)
#   5. test_main's core case keywords are caught by grep (302/404/502 etc.)
#   6. test_registry's core case keywords are caught by grep
#   7. main.py exposes only create_app() at module level (no app = AIMDDispatcher())
#   8. main.py does not import FastAPI/Starlette (ADR-0001 intent)
set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 2

PASS=0
FAIL=0
FAILED=()

check() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        FAILED+=("$label")
        echo "FAIL: $label"
    fi
}

# 1. main.py exists + exposes core symbols
check "main.py exposes AIMDDispatcher" \
    grep -qE "^class AIMDDispatcher" engine/aimd/main.py

check "main.py exposes create_app" \
    grep -qE "^def create_app" engine/aimd/main.py

check "main.py exposes ASGI helpers" \
    bash -c 'grep -qE "^async def _plain" engine/aimd/main.py && grep -qE "^async def _json" engine/aimd/main.py && grep -qE "^async def _redirect" engine/aimd/main.py && grep -qE "^async def _file" engine/aimd/main.py'

# 2. registry.py exists + exposes core symbols
check "registry.py exposes AppRegistry" \
    grep -qE "^class AppRegistry" engine/aimd/registry.py

check "registry.py exposes drop" \
    grep -qE "def drop\(self" engine/aimd/registry.py

# 3. test files exist
check "test_main.py exists" test -f engine/tests/test_main.py
check "test_registry.py exists" test -f engine/tests/test_registry.py

# 4. main.py imports AppRegistry and calls get
check "main.py imports AppRegistry" \
    grep -qE "from \.registry import AppRegistry" engine/aimd/main.py

check "main.py calls registry.get" \
    grep -qE "self\.registry\.get" engine/aimd/main.py

# 5. test_main core case keywords
check "test_main covers root not handled by engine" \
    grep -qE "root_not_handled|root_redirects" engine/tests/test_main.py

check "test_main covers 404 for missing spec" \
    grep -qE "missing_spec.*404|404" engine/tests/test_main.py

check "test_main covers 502 on compile failure" \
    grep -qE "502" engine/tests/test_main.py

check "test_main covers stale serve on recompile failure" \
    grep -qE "stale|serves_stale" engine/tests/test_main.py

check "test_main covers py subapp scope forwarding" \
    grep -qE "root_path.*x\.ai\.md|subapp" engine/tests/test_main.py

# 6. test_registry core case keywords
check "test_registry covers reload on mtime advance" \
    grep -qE "mtime_advance|reload" engine/tests/test_registry.py

check "test_registry covers reload-failure keeps existing app" \
    grep -qE "reload_failure|keeps_existing" engine/tests/test_registry.py

check "test_registry covers drop then reload" \
    grep -qE "drop.*reload|drop_then_get" engine/tests/test_registry.py

# 7. main.py exposes only create_app() at module level
check "main.py does NOT expose app = AIMDDispatcher() at module level" \
    bash -c '! grep -qE "^app = AIMDDispatcher\(\)" engine/aimd/main.py'

check "main.py uses create_app() as factory entry" \
    grep -qE "create_app\(\).*AIMDDispatcher|AIMDDispatcher\(\)" engine/aimd/main.py

# 8. main.py must not import FastAPI/Starlette
check "main.py does NOT import fastapi" \
    bash -c '! grep -qiE "^import fastapi|^from fastapi" engine/aimd/main.py'

check "main.py does NOT import starlette" \
    bash -c '! grep -qiE "^import starlette|^from starlette" engine/aimd/main.py'

echo ""
echo "============================="
echo "verify-issue-10: PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "Failed:"
    for f in "${FAILED[@]}"; do echo "  - $f"; done
    exit 1
fi
exit 0