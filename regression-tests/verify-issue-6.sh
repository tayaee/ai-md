#!/bin/bash
set -e

# 1. Check that the files exist
if [ ! -f "engine/aimd/llm.py" ]; then
    echo "engine/aimd/llm.py does not exist"
    exit 1
fi

if [ ! -f "engine/tests/test_llm.py" ]; then
    echo "engine/tests/test_llm.py does not exist"
    exit 1
fi

# 2. Check required function definitions
grep -q "def chat" "engine/aimd/llm.py" || (echo "chat function missing"; exit 1)
grep -q "def _make_client" "engine/aimd/llm.py" || (echo "_make_client function missing"; exit 1)

# 3. Verify openai is only imported in llm.py (importing openai from other modules is forbidden)
if grep -rl "^import openai\|^from openai" engine/aimd --include="*.py" | grep -v "engine/aimd/llm.py"; then
    echo "openai must only be imported from aimd/llm.py"
    exit 1
fi

# 4. Run tests
cd engine
uv run pytest tests/test_llm.py -q
