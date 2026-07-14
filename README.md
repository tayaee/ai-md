# AI.MD -- AI-powered Markdown Engine

ai.md is a new way of developing simple SPA or REST API applicatio using markdown.
It is human-editable via text editors and directly compiled by the AI.MD engine into
executable applications.

## Use Cases

* SPA (Tetris)

Write your single-page app requirements in src/tetris.ai.md and access
http://localhost:8080/tetris.ai.md. Modifying the file and refreshing the browser
triggers on-the-fly re-compilation.

* REST API (Temperature Conversion)

Define API endpoints in src/convert.ai.md. You can immediately call the compiled
backend service via POST requests.

## Quick Start

1. Create an API key from OpenAI, Anthropic, MiniMax, DeepSeek or OpenRouter.
2. Run `./setup-dotenv.sh` to select provider and configure API key in .env.
3. Run the the engine to Docker: `./deploy-to-docker.sh`
4. (Optional) Take a look at src/*.md for the demo apps.
5. Use browser to hit http://localhost:8080/tetris.ai.md to create and run the Tetris game.
6. Try editing src/tetris.ai.md and reload the URL to re-deploy the app.
7. Run the following on terminal: `curl -X POST localhost:8080/convert.ai.md/convert -H 'Content-Type: application/json' -d '{"temperature": 30, "type": "C"}'`
8. Edit src/convert.ai.md to change the contract, and hit the URL again.

