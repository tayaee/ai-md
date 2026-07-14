#!/bin/bash
set -e

# 1. Verify the regex includes a CRLF-tolerant pattern
if ! grep -q "\\\\r?" "engine/aimd/validators.py"; then
    echo "expected CRLF tolerance (\\r?) in _FENCE_RE not found"
    exit 1
fi

# 2. Regression test for the existing LF case (selects the longest fence block)
cd engine
uv run pytest tests/test_validators.py -q
