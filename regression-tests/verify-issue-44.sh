#!/usr/bin/env bash
# issue-44: compiler._import_gate — treat SystemExit (BaseException) as a validation failure too (regression verification)
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== 1. _import_gate catches SystemExit ==="
grep -q 'except (Exception, SystemExit)' engine/aimd/compiler.py

echo "=== 2. Regression test exists ==="
grep -q 'test_compile_spec_system_exit_from_llm_code_does_not_crash_process' engine/tests/test_compiler.py

echo "=== 3. Unit tests ==="
cd engine && uv run python -m pytest tests/test_compiler.py -q
cd ..

echo "OK: issue-44 regression verification passed"
