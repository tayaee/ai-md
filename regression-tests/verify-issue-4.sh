#!/bin/bash
set -e

# 1. Check that the files exist
if [ ! -f "engine/aimd/validators.py" ]; then
    echo "engine/aimd/validators.py does not exist"
    exit 1
fi

if [ ! -f "engine/tests/test_validators.py" ]; then
    echo "engine/tests/test_validators.py does not exist"
    exit 1
fi

# 2. Check required function definitions
grep -q "def extract_code" "engine/aimd/validators.py" || (echo "extract_code function missing"; exit 1)
grep -q "def validate_html" "engine/aimd/validators.py" || (echo "validate_html function missing"; exit 1)
grep -q "def validate_python" "engine/aimd/validators.py" || (echo "validate_python function missing"; exit 1)
grep -q "def load_module" "engine/aimd/validators.py" || (echo "load_module function missing"; exit 1)

# 3. Run tests
cd engine
uv run pytest tests/test_validators.py -q
