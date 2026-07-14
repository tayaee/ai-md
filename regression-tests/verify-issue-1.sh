#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "FAIL: $1" >&2; exit 1; }

test -f .gitignore || fail ".gitignore missing"
grep -qx '.env' .gitignore || fail ".gitignore does not ignore .env"

test -f .env.example || fail ".env.example missing"
grep -q '^LLM_API_KEY=' .env.example || fail ".env.example missing LLM_API_KEY"

test -f engine/requirements.txt || fail "engine/requirements.txt missing"
test -f engine/requirements-dev.txt || fail "engine/requirements-dev.txt missing"
test -f engine/aimd/__init__.py || fail "engine/aimd/__init__.py missing"
test -f engine/tests/__init__.py || fail "engine/tests/__init__.py missing"
test -f dist/.gitkeep || fail "dist/.gitkeep missing"

test -f src/index.ai.md || fail "src/index.ai.md missing"
test -f src/convert.ai.md || fail "src/convert.ai.md missing"

test -f README.md || fail "README.md missing"
grep -q '^# AIMD — AI-powered Markdown Engine' README.md || fail "README.md missing title"
grep -q 'LLM이 생성한 코드를 그대로 실행' README.md || fail "README.md missing security warning"
grep -qE '\*\*.*ngrok http --basic-auth' README.md || fail "README.md warning not bolded"
grep -q 'docs/SPEC.md' README.md || fail "README.md missing SPEC.md link"
grep -q 'docs/adr' README.md || fail "README.md missing adr link"

test ! -f .env || fail ".env should not exist (only .env.example)"

echo OK
