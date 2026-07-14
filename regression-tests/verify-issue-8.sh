#!/usr/bin/env bash
# issue-8: compiler.py — compile pipeline + per-file lock regression verification
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== 1. compiler.py exists + core signatures ==="
test -f engine/aimd/compiler.py
grep -q '^class CompileError' engine/aimd/compiler.py
grep -q '^def compile_spec' engine/aimd/compiler.py
grep -q '^def _get_lock' engine/aimd/compiler.py
grep -q '_locks: dict\[str, threading.Lock\] = defaultdict(threading.Lock)' engine/aimd/compiler.py

echo "=== 2. test_compiler.py exists ==="
test -f engine/tests/test_compiler.py

echo "=== 3. Uses per-file locking (ADR-0003) + atomic write (ADR-0008) ==="
grep -q '_get_lock(name)' engine/aimd/compiler.py
grep -q 'artifacts.atomic_write' engine/aimd/compiler.py
grep -q 'artifacts.is_stale' engine/aimd/compiler.py

echo "=== 4. Validation strength (ADR-0008) — api is 2-stage (syntax+import), spa uses validate_html ==="
grep -q 'validators.validate_html' engine/aimd/compiler.py
grep -q 'validators.validate_python' engine/aimd/compiler.py
grep -q 'validators.load_module' engine/aimd/compiler.py

echo "=== 5. Exactly one fix retry (no infinite retries) ==="
# llm.chat should appear at exactly two call sites (initial call + one fix retry).
chat_calls=$(grep -c 'llm.chat(' engine/aimd/compiler.py)
if [ "$chat_calls" -ne 2 ]; then
  echo "FAIL: llm.chat is not called exactly twice (found: $chat_calls) — risk of infinite retries" >&2
  exit 1
fi

echo "=== 6. No asyncio usage (pure sync) ==="
if grep -qE '^import asyncio|^from asyncio' engine/aimd/compiler.py; then
  echo "FAIL: compiler.py must be a pure sync module (asyncio forbidden)" >&2
  exit 1
fi

echo "=== 7. Unit tests ==="
cd engine && uv run python -m pytest tests/test_compiler.py -q
cd ..

echo "OK: issue-8 regression verification passed"
