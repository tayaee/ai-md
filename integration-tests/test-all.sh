#!/bin/bash
# integration-tests/test-all.sh
#
# Sequential integration test across every supported LLM provider (Ubuntu/WSL).
# See integration-tests/README.md-equivalent context in the repo history (grill-me
# session) for the design rationale. Flow per provider:
#   Flow A (cache/watcher): tetris.ai.md / convert.ai.md (committed prebuilt
#     artifacts) -- verifies prebuilt-serving, background rebuild-on-touch via
#     the watcher, and that a settled cache serves without a further LLM call.
#   Flow B (real generation): src/<llm>/tetris.ai.md, src/<llm>/convert.ai.md
#     (fresh copies with no prebuilt dist counterpart) -- verifies the LLM is
#     actually invoked end-to-end for that provider.
set -uo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
TMP_DIR="$REPO_ROOT/tmp/$TS"
mkdir -p "$TMP_DIR"
SUMMARY_LOG="$TMP_DIR/summary.log"
: > "$SUMMARY_LOG"

LLM_NAMES=(sonnet deepseek minimax openai openrouter)
KEY_VARS=(ANTHROPIC_API_KEY DEEPSEEK_API_KEY MINIMAX_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY)

PASS_COUNT=0
FAIL_COUNT=0

record() {
    # record <PASS|FAIL|SKIP|WARN> <item> <message>
    local status="$1" item="$2" msg="$3"
    printf '[%s] %-28s %s\n' "$status" "$item" "$msg" | tee -a "$SUMMARY_LOG"
    case "$status" in
        PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    esac
}

engine_logs() {
    docker compose logs engine 2>/dev/null
}

engine_log_lines() {
    engine_logs | wc -l | tr -d ' '
}

engine_log_since() {
    # engine_log_since <marker-line-count>
    engine_logs | tail -n "+$(( $1 + 1 ))"
}

# -- 1. Dependency checks --------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
    record FAIL docker "docker not found. Install: https://docs.docker.com/engine/install/"
    exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
    record FAIL docker-compose "'docker compose' plugin not available"
    exit 1
fi
record PASS docker "docker + compose plugin available"

available_llms=()
for i in "${!LLM_NAMES[@]}"; do
    name="${LLM_NAMES[$i]}"
    keyvar="${KEY_VARS[$i]}"
    if [ -n "${!keyvar:-}" ]; then
        available_llms+=("$name")
        record PASS "api-key:$name" "$keyvar is set"
    else
        record WARN "api-key:$name" "$keyvar not set -- $name will be SKIPPED"
    fi
done
if [ "${#available_llms[@]}" -eq 0 ]; then
    record FAIL api-keys "no *_API_KEY is set for any provider -- cannot continue"
    exit 1
fi

# -- 2. Cleanup + build once ------------------------------------------------

for name in "${LLM_NAMES[@]}"; do
    rm -rf "$REPO_ROOT/src/$name" "$REPO_ROOT/dist/$name"
done
bash "$REPO_ROOT/undeploy.sh" >>"$TMP_DIR/undeploy-initial.log" 2>&1
git checkout -- dist/tetris.ai.md.html dist/convert.ai.md.py 2>>"$TMP_DIR/undeploy-initial.log" || true
record PASS cleanup "prior test artifacts removed, prebuilt dist restored"

if ! bash "$REPO_ROOT/build.sh" >"$TMP_DIR/build.log" 2>&1; then
    record FAIL build "docker compose build failed -- see $TMP_DIR/build.log"
    exit 1
fi
record PASS build "docker compose build succeeded"

PORT="$(bash "$REPO_ROOT/integration-tests/find-free-port.sh" 18080)"
if [ -z "$PORT" ]; then
    record FAIL port "could not find a free port from 18080"
    exit 1
fi
export NGINX_PORT="$PORT"
record PASS port "using NGINX_PORT=$PORT"
BASE_URL="http://localhost:$PORT"

# -- 3. Per-provider verification -------------------------------------------

wait_for_mtime_change() {
    # wait_for_mtime_change <path> <old_mtime> <timeout_s>
    local path="$1" old="$2" timeout="$3" waited=0
    while [ "$waited" -lt "$timeout" ]; do
        if [ -f "$path" ]; then
            new="$(stat -c %Y "$path" 2>/dev/null || echo "$old")"
            if [ "$new" != "$old" ]; then
                return 0
            fi
        fi
        sleep 1
        waited=$((waited + 1))
    done
    return 1
}

verify_flow_a_spa() {
    # verify_flow_a_spa <llm> <spec-name e.g. tetris.ai.md> <log-file>
    local llm="$1" spec="$2" log="$3"
    local src_path="$REPO_ROOT/src/$spec"
    local dist_path="$REPO_ROOT/dist/$spec.html"

    local mark1 http1 time1
    mark1="$(engine_log_lines)"
    http1=$(curl -s -o "$TMP_DIR/${llm}-${spec}-hit1.html" -w '%{http_code} %{time_total}' "$BASE_URL/$spec")
    code1="${http1%% *}"; t1="${http1##* }"
    if [ "$code1" = "200" ] && awk -v t="$t1" 'BEGIN{exit !(t<2)}'; then
        record PASS "$llm:$spec:prebuilt-hit1" "http=$code1 time=${t1}s"
    else
        record FAIL "$llm:$spec:prebuilt-hit1" "http=$code1 time=${t1}s"
    fi
    if engine_log_since "$mark1" | grep -q "compile start name=$spec"; then
        record FAIL "$llm:$spec:prebuilt-no-llm-call" "unexpected compile on first hit"
    else
        record PASS "$llm:$spec:prebuilt-no-llm-call" "no compile triggered, served from committed dist/"
    fi

    old_mtime="$(stat -c %Y "$dist_path" 2>/dev/null || echo 0)"
    touch "$src_path"
    if wait_for_mtime_change "$dist_path" "$old_mtime" 30; then
        record PASS "$llm:$spec:rebuild-mtime" "dist artifact mtime changed after touch (watcher rebuild)"
    else
        record FAIL "$llm:$spec:rebuild-mtime" "dist artifact was not rebuilt within 30s"
    fi
    if engine_log_since "$mark1" | grep -q "compile ok name=$spec"; then
        record PASS "$llm:$spec:rebuild-log" "engine log confirms compile ok for $spec"
    else
        record FAIL "$llm:$spec:rebuild-log" "no 'compile ok name=$spec' found in engine log"
    fi

    mark2="$(engine_log_lines)"
    http3=$(curl -s -o "$TMP_DIR/${llm}-${spec}-hit3.html" -w '%{http_code} %{time_total}' "$BASE_URL/$spec")
    code3="${http3%% *}"; t3="${http3##* }"
    if [ "$code3" = "200" ] && awk -v t="$t3" 'BEGIN{exit !(t<2)}'; then
        record PASS "$llm:$spec:recache-hit3" "http=$code3 time=${t3}s"
    else
        record FAIL "$llm:$spec:recache-hit3" "http=$code3 time=${t3}s"
    fi
    if engine_log_since "$mark2" | grep -q "compile start name=$spec"; then
        record FAIL "$llm:$spec:recache-no-llm-call" "unexpected compile on settled re-hit"
    else
        record PASS "$llm:$spec:recache-no-llm-call" "no additional LLM call after rebuild settled"
    fi
}

verify_flow_a_api() {
    # verify_flow_a_api <llm> <spec-name e.g. convert.ai.md> <log-file>
    local llm="$1" spec="$2" log="$3"
    local src_path="$REPO_ROOT/src/$spec"
    local dist_path="$REPO_ROOT/dist/$spec.py"

    local mark1
    mark1="$(engine_log_lines)"
    http1=$(curl -s -o /dev/null -w '%{http_code} %{time_total}' "$BASE_URL/$spec")
    code1="${http1%% *}"; t1="${http1##* }"
    # py artifact GET with no subpath redirects (302) to /docs -- that's the
    # "prebuilt, served without compiling" signal for an api target.
    if [ "$code1" = "302" ] && awk -v t="$t1" 'BEGIN{exit !(t<2)}'; then
        record PASS "$llm:$spec:prebuilt-hit1" "http=$code1 time=${t1}s (redirect to /docs)"
    else
        record FAIL "$llm:$spec:prebuilt-hit1" "http=$code1 time=${t1}s"
    fi
    if engine_log_since "$mark1" | grep -q "compile start name=$spec"; then
        record FAIL "$llm:$spec:prebuilt-no-llm-call" "unexpected compile on first hit"
    else
        record PASS "$llm:$spec:prebuilt-no-llm-call" "no compile triggered, served from committed dist/"
    fi

    old_mtime="$(stat -c %Y "$dist_path" 2>/dev/null || echo 0)"
    touch "$src_path"
    if wait_for_mtime_change "$dist_path" "$old_mtime" 30; then
        record PASS "$llm:$spec:rebuild-mtime" "dist artifact mtime changed after touch (watcher rebuild)"
    else
        record FAIL "$llm:$spec:rebuild-mtime" "dist artifact was not rebuilt within 30s"
    fi
    if engine_log_since "$mark1" | grep -q "compile ok name=$spec"; then
        record PASS "$llm:$spec:rebuild-log" "engine log confirms compile ok for $spec"
    else
        record FAIL "$llm:$spec:rebuild-log" "no 'compile ok name=$spec' found in engine log"
    fi

    mark2="$(engine_log_lines)"
    http3=$(curl -s -o /dev/null -w '%{http_code} %{time_total}' "$BASE_URL/$spec")
    code3="${http3%% *}"; t3="${http3##* }"
    if [ "$code3" = "302" ] && awk -v t="$t3" 'BEGIN{exit !(t<2)}'; then
        record PASS "$llm:$spec:recache-hit3" "http=$code3 time=${t3}s"
    else
        record FAIL "$llm:$spec:recache-hit3" "http=$code3 time=${t3}s"
    fi
    if engine_log_since "$mark2" | grep -q "compile start name=$spec"; then
        record FAIL "$llm:$spec:recache-no-llm-call" "unexpected compile on settled re-hit"
    else
        record PASS "$llm:$spec:recache-no-llm-call" "no additional LLM call after rebuild settled"
    fi
}

verify_flow_b() {
    # verify_flow_b <llm> <relative-spec e.g. sonnet/tetris.ai.md> <expect-code>
    local llm="$1" spec="$2" expect_code="$3"
    local mark
    mark="$(engine_log_lines)"
    http1=$(curl -s -o "$TMP_DIR/${llm}-$(basename "$spec")-fresh.out" -w '%{http_code} %{time_total}' "$BASE_URL/$spec")
    code1="${http1%% *}"; t1="${http1##* }"
    if [ "$code1" = "$expect_code" ]; then
        record PASS "$llm:$spec:fresh-generate" "http=$code1 time=${t1}s"
    else
        record FAIL "$llm:$spec:fresh-generate" "http=$code1 time=${t1}s (expected $expect_code)"
    fi
    if engine_log_since "$mark" | grep -q "llm call start"; then
        record PASS "$llm:$spec:llm-invoked" "engine log shows a real LLM call was made"
    else
        record FAIL "$llm:$spec:llm-invoked" "no 'llm call start' found in engine log -- LLM was not actually invoked"
    fi
}

for name in "${LLM_NAMES[@]}"; do
    keyvar_index=-1
    for i in "${!LLM_NAMES[@]}"; do
        [ "${LLM_NAMES[$i]}" = "$name" ] && keyvar_index=$i
    done
    if [[ ! " ${available_llms[*]} " == *" $name "* ]]; then
        continue
    fi

    echo "=== $name ===" | tee -a "$SUMMARY_LOG"
    LOGFILE="$TMP_DIR/$name-engine.log"

    if ! bash "$REPO_ROOT/deploy-with-$name.sh" >"$TMP_DIR/$name-deploy.log" 2>&1; then
        record FAIL "$name:deploy" "deploy-with-$name.sh failed -- see $TMP_DIR/$name-deploy.log"
        continue
    fi

    sleep 5
    if engine_logs | grep -iq "ERROR"; then
        record FAIL "$name:no-errors" "engine log contains ERROR after startup"
        engine_logs > "$LOGFILE"
    else
        record PASS "$name:no-errors" "no ERROR in engine log after 5s"
    fi

    verify_flow_a_spa "$name" "tetris.ai.md" "$LOGFILE"
    verify_flow_a_api "$name" "convert.ai.md" "$LOGFILE"

    mkdir -p "$REPO_ROOT/src/$name"
    cp "$REPO_ROOT/src/tetris.ai.md" "$REPO_ROOT/src/$name/tetris.ai.md"
    cp "$REPO_ROOT/src/convert.ai.md" "$REPO_ROOT/src/$name/convert.ai.md"
    verify_flow_b "$name" "$name/tetris.ai.md" "200"
    verify_flow_b "$name" "$name/convert.ai.md" "302"

    engine_logs > "$LOGFILE"

    bash "$REPO_ROOT/undeploy.sh" >>"$TMP_DIR/$name-undeploy.log" 2>&1
    git checkout -- dist/tetris.ai.md.html dist/convert.ai.md.py 2>>"$TMP_DIR/$name-undeploy.log" || true
    # src/<name> and dist/<name> are intentionally kept for post-run inspection.
done

echo "" | tee -a "$SUMMARY_LOG"
echo "PASS=$PASS_COUNT FAIL=$FAIL_COUNT (detailed logs: $TMP_DIR)" | tee -a "$SUMMARY_LOG"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
