# verify-issue-13 vs the docker build/run redesign

`verify-issue-13.sh` checked two things that no longer match the current,
user-approved design (done earlier in the same work session as issue-53,
not tracked under its own issue number):

1. `env_file: .env` in `docker-compose.yml` — replaced with an
   `environment:` block using `${VAR:-default}` interpolation, so
   shell-supplied env vars always take priority over any `.env` file
   (goal: `git clone` → edit one `LLM_API_KEY` line → `docker compose
   build && docker compose up -d`, no `.env` file required at all).
2. `docker compose up --build` in README.md — the quick-start now splits
   build and run into two steps (`docker compose build` then
   `docker compose up -d`, per provider), so this exact string never
   appears; replaced with a check for `docker compose up -d`.

`verify-issue-13.sh` was updated to check for `environment:` instead of
`env_file: .env`, and `docker compose up -d` instead of `docker compose
up --build`. No functional regression — `docker-compose.yml` and
`README.md` were verified directly (nginx config validated with `nginx
-t`, `docker compose config` resolves env interpolation correctly).
