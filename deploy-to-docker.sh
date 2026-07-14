#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

if [ ! -f .env ]; then
  echo "No .env file found. Running setup..."
  ./scripts/setup-dotenv.sh
fi

if [ ! -f .env ]; then
  echo "Failed to create .env." >&2
  exit 1
fi

echo "Starting AI.MD with docker compose..."
docker compose up -d --build

echo ""
echo "AI.MD is running."
echo "Open http://localhost:8080/tetris.ai.md"
