#!/bin/bash
set -e

# 1. Check that the files exist
if [ ! -f "engine/aimd/prompts.py" ]; then
    echo "engine/aimd/prompts.py does not exist"
    exit 1
fi

if [ ! -f "engine/tests/test_prompts.py" ]; then
    echo "engine/tests/test_prompts.py does not exist"
    exit 1
fi

# 2. Check required constant definitions
grep -q "^CLASSIFY_SYSTEM" "engine/aimd/prompts.py" || (echo "CLASSIFY_SYSTEM constant missing"; exit 1)
grep -q "^SPA_SYSTEM" "engine/aimd/prompts.py" || (echo "SPA_SYSTEM constant missing"; exit 1)
grep -q "^API_SYSTEM" "engine/aimd/prompts.py" || (echo "API_SYSTEM constant missing"; exit 1)
grep -q "^FIX_TEMPLATE" "engine/aimd/prompts.py" || (echo "FIX_TEMPLATE constant missing"; exit 1)

# 3. Verify no functions/classes are included (file must contain only the 4 constants)
if grep -qE "^(def |class )" "engine/aimd/prompts.py"; then
    echo "prompts.py must contain constants only, no functions/classes"
    exit 1
fi

# 4. Run tests
cd engine
uv run pytest tests/test_prompts.py -q
