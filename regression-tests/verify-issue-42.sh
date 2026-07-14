#!/usr/bin/env bash
# issue-42: unify classify log format regression verification
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== 1. classifier.py's unexpected-answer log follows the spec format ==="
# Check that the "LLM classification returned unexpected answer" branch is gone
if grep -q '"LLM classification returned unexpected answer' engine/aimd/classifier.py; then
  echo "FAIL: classifier.py still has the unexpected-answer branch log" >&2
  exit 1
fi
# Both log calls must use the same format
COUNT=$(grep -c 'LLM classification failed, falling back to keywords' engine/aimd/classifier.py)
if [ "$COUNT" -lt 2 ]; then
  echo "FAIL: unified log format only appears ${COUNT} time(s) (must be 2 or more)" >&2
  exit 1
fi

echo "=== 2. test_classifier.py has a log-format verification test ==="
grep -q 'test_classify_logs_unified_format_on_unexpected_answer' engine/tests/test_classifier.py
grep -q 'test_classify_logs_unified_format_on_exception' engine/tests/test_classifier.py

echo "=== 3. Unit tests ==="
cd engine && uv run python -m pytest tests/test_classifier.py -q
cd ..

echo "OK: issue-42 regression verification passed"