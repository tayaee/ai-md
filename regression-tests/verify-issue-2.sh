#!/bin/bash
set -e

# 1. Check that the files exist
if [ ! -f "engine/aimd/config.py" ]; then
    echo "engine/aimd/config.py does not exist"
    exit 1
fi

if [ ! -f "engine/tests/test_config.py" ]; then
    echo "engine/tests/test_config.py does not exist"
    exit 1
fi

# 2. Check required definitions
grep -q "class Settings" "engine/aimd/config.py" || (echo "Settings class missing"; exit 1)
grep -q "def load_settings" "engine/aimd/config.py" || (echo "load_settings function missing"; exit 1)

# 3. Run tests
cd engine
uv run pytest tests/test_config.py -q
