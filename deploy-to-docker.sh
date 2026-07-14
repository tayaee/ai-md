#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

# LLM_API_KEY (and optionally LLM_BASE_URL / LLM_MODEL / LLM_API_PROTOCOL /
# LLM_MAX_TOKENS) must already be exported in the shell, e.g.:
#   LLM_API_KEY=sk-xxxx LLM_BASE_URL=https://api.openai.com/v1 \
#     LLM_MODEL=gpt-5.4 LLM_API_PROTOCOL=openai ./deploy-to-docker.sh
# See README.md for per-provider examples.

echo "1) Building the docker image..."
docker compose build

echo ""
echo "2) Creating/starting the containers..."
docker compose up -d

echo ""
echo "AI.MD is running."
echo "Open http://localhost:8080/"
