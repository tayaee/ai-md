#!/bin/bash
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "=== 1. Checking engine/Dockerfile ==="
if [ ! -f "engine/Dockerfile" ]; then
    echo "ERROR: engine/Dockerfile not found"
    exit 1
fi
grep -q "FROM python:3.12-slim" engine/Dockerfile
grep -q "WORKDIR /opt/aimd" engine/Dockerfile
grep -q "useradd -u 1000 -m aimd" engine/Dockerfile
grep -q "USER aimd" engine/Dockerfile
grep -q "aimd.main:create_app" engine/Dockerfile
echo "Dockerfile checked successfully."

echo "=== 2. Checking docker-compose.yml ==="
if [ ! -f "docker-compose.yml" ]; then
    echo "ERROR: docker-compose.yml not found"
    exit 1
fi
grep -q "build: ./engine" docker-compose.yml
# env_file: .env was replaced by environment:/${VAR:-default} interpolation
# so shell-supplied env vars always take priority over any .env file (see
# regression-tests/verify-issue-13.conflict-with-docker-env-redesign.md).
grep -q "environment:" docker-compose.yml
grep -q "ports:" docker-compose.yml
grep -q "8080:80" docker-compose.yml
grep -q "depends_on:" docker-compose.yml
echo "docker-compose.yml checked successfully."

echo "=== 3. Checking README.md ==="
grep -q "docker compose up -d" README.md
grep -q "localhost:8080" README.md
echo "README.md checked successfully."

# Docker check
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    echo "=== 4. Running Docker Compose Config ==="
    # Backup .env if exists
    ENV_BACKUP=0
    if [ -f .env ]; then
        mv .env .env.bak
        ENV_BACKUP=1
    fi
    
    echo "LLM_API_KEY=dummy" > .env
    
    # Run docker compose config
    if ! docker compose config >/dev/null; then
        echo "ERROR: docker compose config failed"
        rm -f .env
        [ "$ENV_BACKUP" -eq 1 ] && mv .env.bak .env
        exit 1
    fi
    
    echo "=== 5. Running Docker Compose Build ==="
    if ! docker compose build; then
        echo "ERROR: docker compose build failed"
        rm -f .env
        [ "$ENV_BACKUP" -eq 1 ] && mv .env.bak .env
        exit 1
    fi
    
    echo "=== 6. Running Docker Compose Up and Curl Verification ==="
    docker compose up -d
    
    # Wait for nginx/engine to be ready
    echo "Waiting for services to start..."
    sleep 3
    
    # Test nonexistent.ai.md returns 404
    STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/nonexistent.ai.md || echo "000")
    echo "Response status code: $STATUS_CODE"
    
    # Clean up containers
    docker compose down
    
    # Restore .env
    rm -f .env
    [ "$ENV_BACKUP" -eq 1 ] && mv .env.bak .env
    
    if [ "$STATUS_CODE" -ne 404 ]; then
        echo "ERROR: Expected 404, got $STATUS_CODE"
        exit 1
    fi
    echo "Docker based validation succeeded!"
else
    echo "Warning: Docker is not installed or running. Skipping Docker-based validation."
fi

exit 0
