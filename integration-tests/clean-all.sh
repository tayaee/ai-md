#!/bin/bash
# clean-all.sh
# Tears down every stack integration-tests/test-all.sh can leave behind
# (ai-md-<llm> per-provider projects + the default ai-md project) and
# removes the local artifacts those runs generate.
set +e

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 1

LLM_NAMES="sonnet deepseek minimax openai openrouter"

echo "Undeploying default ai-md project..."
docker compose down >/dev/null 2>&1

for name in $LLM_NAMES; do
    echo "Undeploying ai-md-$name..."
    docker compose -p "ai-md-$name" down >/dev/null 2>&1
    rm -rf "src/$name" "dist/$name"
done

echo "Restoring committed dist/ artifacts..."
git checkout -- dist/tetris.ai.md.html dist/convert.ai.md.py 2>/dev/null

echo "Removing tmp/*..."
rm -rf tmp/*

echo "Done."
