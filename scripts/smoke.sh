#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== E2E Smoke Test ==="

# Docker Check
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    echo "Docker environment detected. Running full container E2E Smoke Test..."
    
    # 1. Back up existing dist artifacts if any
    BACKUP_DIST=0
    if [ -d dist ]; then
        mv dist dist.bak
        BACKUP_DIST=1
    fi
    mkdir -p dist
    
    # 2. Write temp stub artifacts for smoke test
    echo "Writing stub artifacts..."
    echo "<!DOCTYPE html><html><body>SMOKE</body></html>" > dist/index.ai.md.html
    cat << 'EOF' > dist/convert.ai.md.py
from fastapi import FastAPI
app = FastAPI()
@app.post("/convert")
def convert():
    return {"result": 86.0}
EOF

    # 3. Touch specs back in time to prevent recompile
    touch -d '2000-01-01' src/*.ai.md
    
    # 4. Start compose
    echo "Starting docker compose..."
    LLM_API_KEY=dummy docker compose up -d --build
    
    # Wait for nginx/engine to be up
    echo "Waiting for services..."
    sleep 4
    
    # 5. Run curls
    echo "Running E2E Curl verifications..."
    
    # Test 1: GET / -> 302, location /index.ai.md
    LOC=$(curl -s -I http://localhost:8080/ | grep -i "location:" | tr -d '\r')
    echo "Redirect Location: $LOC"
    if [[ "$LOC" != *"index.ai.md"* ]]; then
        echo "Error: Redirect to index.ai.md failed"
        docker compose down
        exit 1
    fi
    
    # Test 2: GET /index.ai.md -> 200 + SMOKE
    BODY=$(curl -s http://localhost:8080/index.ai.md)
    if [[ "$BODY" != *"SMOKE"* ]]; then
        echo "Error: index.ai.md body does not contain SMOKE"
        docker compose down
        exit 1
    fi
    
    # Test 3: GET /convert.ai.md -> 200 (Swagger)
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L http://localhost:8080/convert.ai.md)
    if [ "$STATUS" -ne 200 ]; then
        echo "Error: convert.ai.md docs returned $STATUS"
        docker compose down
        exit 1
    fi
    
    # Test 4: POST /convert.ai.md/convert -> json with "result"
    RES=$(curl -s -X POST http://localhost:8080/convert.ai.md/convert -H 'Content-Type: application/json' -d '{"temperature": 30, "type": "C"}')
    echo "POST response: $RES"
    if [[ "$RES" != *"result"* ]]; then
        echo "Error: POST response does not contain 'result'"
        docker compose down
        exit 1
    fi
    
    # Test 5: GET /nonexistent.ai.md -> 404
    STATUS_404=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/nonexistent.ai.md)
    if [ "$STATUS_404" -ne 404 ]; then
        echo "Error: nonexistent.ai.md returned $STATUS_404"
        docker compose down
        exit 1
    fi
    
    # 6. Tear down
    echo "Tearing down compose..."
    docker compose down
    
    # 7. Restore backup
    rm -rf dist
    if [ "$BACKUP_DIST" -eq 1 ]; then
        mv dist.bak dist
    fi
    
    echo "Full container E2E Smoke Test succeeded!"
else
    echo "Warning: Docker is not installed or running. Running offline validation..."
    
    # Offline check: verify our actual generated dist files exist and are correct
    if [ ! -f "dist/index.ai.md.html" ]; then
        echo "Error: dist/index.ai.md.html is missing"
        exit 1
    fi
    if [ ! -f "dist/convert.ai.md.py" ]; then
        echo "Error: dist/convert.ai.md.py is missing"
        exit 1
    fi
    
    # Check key contents of dist files
    grep -q "AIMD Tetris" dist/index.ai.md.html
    grep -q "fastapi" dist/convert.ai.md.py
    grep -q "convert_temp" dist/convert.ai.md.py
    
    echo "Offline static checks passed!"
fi

exit 0
