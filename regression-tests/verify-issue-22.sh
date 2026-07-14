#!/bin/bash
set -e

# Verify the regex allows a single space right after ``` (single-quoted to avoid backtick parsing)
if ! grep -q '``` ?\[a-zA-Z' "engine/aimd/validators.py"; then
    echo "expected '\`\`\` ?[a-zA-Z...' pattern not found in validators.py"
    exit 1
fi

# Full regression test
cd engine
uv run pytest tests/test_validators.py -q
