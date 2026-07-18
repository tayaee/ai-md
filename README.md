# AI.MD -- Nano Web Framework Translating Markdown Into Web Application Instantly.

`ai.md` is a new way of developing simple SPA (single page application) or REST API applications using markdown.
It is human-editable via text editors and directly compiled by the AI.MD engine into executable applications.
AI (LLM) will automatically determine the type of application (either SPA or REST API) based on your description.
Just drop a new file with the extension `.ai.md` into `src/` and see your application instantly in the browser.

## Demo Use Cases
* SPA (Tetris)

  Write your single-page app requirements in `src/tetris.ai.md` (or you name it) and access http://localhost:8080/tetris.ai.md. Modifying the file and refreshing the browser triggers on-the-fly re-compilation.

  <img src="images/spa-demo.png" alt="SPA Demo" width="555" height="640">

* REST API (Temperature Conversion)

  Define API endpoints in `src/convert.ai.md` (or you name it). You can immediately call the compiled backend service via POST requests.

  <img src="images/rest-api-demo.png" alt="REST API Demo" width="554" height="639">

## Quick Start
### Prerequisites
* Linux or WSL
* Docker
* API Key from OpenAI or MiniMax 

### Instruction (Linux/WSL only)
* Clone the repo
    ```
    git clone https://github.com/tayaee/web-framework-ai-md.git
    cd web-framework-ai-md
    ```
* First time deployment to Docker
    
    ```
    export LLM_API_KEY=$OPENAI_API_KEY
    ./build.sh
    ./deploy-with-openai.sh
    ```
* Open http://localhost:8080/ and try out the demo app Tetris
* Try editing `src/tetris.ai.md` with additional requirements. It will trigger app rebuild.
* Reload the URL after a few seconds later. Find your app cache at `dist/`. Those will be re-used during the next container runs.
* Clean it up.
    ```
    ./undeploy-openai.sh
    ```
## Verified Configuration
* WSL2 + Docker Desktop + Minimax/OpenAI
