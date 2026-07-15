@echo off
setlocal enabledelayedexpansion

rem clean-all.bat
rem Tears down every stack integration-tests\test-all.bat can leave behind
rem (ai-md-<llm> per-provider projects + the default ai-md project) and
rem removes the local artifacts those runs generate.

rem Resolve repo root from the script's own location (not `git rev-parse
rem --show-toplevel`): under Docker Desktop's WSL integration, git.exe run
rem from a drive-mapped WSL path reports the toplevel as a \\wsl.localhost\...
rem UNC path, which `cd /d` cannot use as CWD.
for %%I in ("%~dp0..") do set "REPO_ROOT=%%~fI"
if not exist "%REPO_ROOT%\.git" (
    echo [FAIL] repo-root could not verify repo root: no .git at "%REPO_ROOT%"
    exit /b 1
)
cd /d "%REPO_ROOT%"

set "LLM_NAMES=sonnet deepseek minimax openai openrouter"

echo Undeploying default ai-md project...
docker compose down >nul 2>&1

for %%n in (%LLM_NAMES%) do (
    echo Undeploying ai-md-%%n...
    docker compose -p ai-md-%%n down >nul 2>&1
    if exist "%REPO_ROOT%\src\%%n" rmdir /s /q "%REPO_ROOT%\src\%%n"
    if exist "%REPO_ROOT%\dist\%%n" rmdir /s /q "%REPO_ROOT%\dist\%%n"
)

echo Restoring committed dist/ artifacts...
git checkout -- dist/tetris.ai.md.html dist/convert.ai.md.py 2>nul

echo Removing tmp\*...
if exist "%REPO_ROOT%\tmp" rmdir /s /q "%REPO_ROOT%\tmp"

echo Done.
exit /b 0
