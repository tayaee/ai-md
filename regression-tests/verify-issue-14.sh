#!/bin/bash
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "=== 1. Checking dist files (Frozen Artifacts) ==="
if [ ! -f "dist/index.ai.md.html" ]; then
    echo "ERROR: dist/index.ai.md.html not found"
    exit 1
fi
if [ ! -f "dist/convert.ai.md.py" ]; then
    echo "ERROR: dist/convert.ai.md.py not found"
    exit 1
fi
echo "dist files checked successfully."

echo "=== 2. Checking scripts/smoke.sh ==="
if [ ! -f "scripts/smoke.sh" ]; then
    echo "ERROR: scripts/smoke.sh not found"
    exit 1
fi
if [ ! -x "scripts/smoke.sh" ]; then
    echo "ERROR: scripts/smoke.sh is not executable"
    exit 1
fi
echo "scripts/smoke.sh checked successfully."

echo "=== 3. Checking README.md ==="
grep -q "Real compile demo" README.md
echo "README.md checked successfully."

echo "=== 4. Running scripts/smoke.sh ==="
bash scripts/smoke.sh
echo "smoke.sh executed successfully."

exit 0
