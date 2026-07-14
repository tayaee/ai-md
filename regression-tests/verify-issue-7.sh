#!/usr/bin/env bash
# issue-7: classifier.py — SPA/API classification regression verification
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== 1. classifier.py exists + Target/classify/classify_by_keywords signatures ==="
test -f engine/aimd/classifier.py
grep -q '^Target = Literal\["spa", "api"\]' engine/aimd/classifier.py
grep -q '^def classify_by_keywords' engine/aimd/classifier.py
grep -q '^def classify' engine/aimd/classifier.py

echo "=== 2. test_classifier.py exists ==="
test -f engine/tests/test_classifier.py

echo "=== 3. classify passes CLASSIFY_SYSTEM to llm.chat ==="
grep -q 'CLASSIFY_SYSTEM' engine/aimd/classifier.py
grep -q 'classifier.llm, "chat"' engine/tests/test_classifier.py

echo "=== 4. No caching allowed (ADR-0005) — no @lru_cache or similar decorator ==="
if grep -qE 'lru_cache|cache\(' engine/aimd/classifier.py; then
  echo "FAIL: classifier.py has traces of caching" >&2
  exit 1
fi

echo "=== 5. Unit tests ==="
cd engine && uv run python -m pytest tests/test_classifier.py -q
cd ..

echo "OK: issue-7 regression verification passed"