#!/usr/bin/env bash
# verify-issue-19 — verifies that engine/aimd/artifacts.py's list_specs
# returns [] without crashing when src_dir is abnormal (a plain file, no
# permissions). issue-19 (fixing issue-3) regression protection script.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "FAIL: $1" >&2; exit 1; }

TARGET=engine/aimd/artifacts.py
test -f "$TARGET" || fail "$TARGET missing"

# 1) list_specs' body must have either an existence/is-directory guard on
#    src_dir, or OSError handling. Either is OK — the issue allows both
#    "is_dir check" and "try-except OSError".
if ! grep -A6 'def list_specs' "$TARGET" | grep -qE 'is_dir\(\)|OSError'; then
  fail "$TARGET list_specs lacks the non-directory / OSError guard"
fi

# 2) Verify the normal *.ai.md sorted-return spec is unchanged — existing
#    core logic is preserved. issue-53 switched the filter mechanism from a
#    flat iterdir()+endswith(".ai.md") scan to a recursive rglob("*.ai.md")
#    (see regression-tests/verify-issue-19.conflict-with-53.md), so either
#    form is accepted here.
grep -qE 'endswith\(".ai.md"\)|rglob\("\*.ai.md"\)' "$TARGET" \
  || fail "$TARGET list_specs lost the .ai.md suffix filter"
grep -q 'sorted(' "$TARGET" \
  || fail "$TARGET list_specs lost the sorted() return"

# 3) Verify all artifacts unit tests pass — direct evidence this change did
#    not break existing behavior.
cd engine
uv run pytest tests/test_artifacts.py -q >/dev/null \
  || fail "engine/tests/test_artifacts.py failed after list_specs change"
cd ..

echo OK