@echo off
setlocal enabledelayedexpansion

rem integration-tests/test-all.bat
rem Sequential integration test across every supported LLM provider (Windows 10).
rem Mirrors integration-tests/test-all.sh. Uses PowerShell one-liners for the
rem bits batch can't do cleanly (mtime compare, log-since-marker, curl timing).

rem DEBUG-ECHO: block below tags commands for first-run verification
rem Resolve REPO_ROOT from the script's own location instead of `git rev-parse
rem --show-toplevel`: under Docker Desktop's WSL integration, git.exe run from
rem a drive-mapped WSL path (e.g. G:\...) reports the toplevel as a
rem \\wsl.localhost\... UNC path, which `cd /d` cannot use as CWD ("CMD does
rem not support UNC paths as current directories"), leaving CWD unchanged and
rem breaking every relative docker compose volume mount downstream.
echo [DEBUG] resolve repo root from script location (%~dp0), verify via .git
for %%I in ("%~dp0..") do set "REPO_ROOT=%%~fI"
if not exist "%REPO_ROOT%\.git" (
    echo [FAIL] repo-root could not verify repo root: no .git at "%REPO_ROOT%"
    exit /b 1
)
echo [DEBUG] repo root verified: "%REPO_ROOT%" ^(.git found^)
echo [DEBUG] cd /d "%REPO_ROOT%"
cd /d "%REPO_ROOT%"
echo [DEBUG] CWD is now: %CD%

echo [DEBUG] powershell Get-Date
for /f "delims=" %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%t"
set "TMP_DIR=%REPO_ROOT%\tmp\%TS%"
echo [DEBUG] mkdir "%TMP_DIR%"
mkdir "%TMP_DIR%" >nul 2>&1
set "SUMMARY_LOG=%TMP_DIR%\summary.log"
type nul > "%SUMMARY_LOG%"

set "LLM_NAMES=sonnet deepseek minimax openai openrouter"
set /a PASS_COUNT=0
set /a FAIL_COUNT=0

rem -- 1. Dependency checks --------------------------------------------------

echo [DEBUG] where docker
where docker >nul 2>&1
if errorlevel 1 (
    call :record FAIL docker "docker not found. Install: https://docs.docker.com/desktop/setup/install/windows-install/"
    exit /b 1
)
echo [DEBUG] docker compose version
docker compose version >nul 2>&1
if errorlevel 1 (
    call :record FAIL docker-compose "'docker compose' plugin not available"
    exit /b 1
)
call :record PASS docker "docker + compose plugin available"

set "AVAILABLE_LLMS="
call :check_key sonnet ANTHROPIC_API_KEY
call :check_key deepseek DEEPSEEK_API_KEY
call :check_key minimax MINIMAX_API_KEY
call :check_key openai OPENAI_API_KEY
call :check_key openrouter OPENROUTER_API_KEY

if "%AVAILABLE_LLMS%"=="" (
    call :record FAIL api-keys "no *_API_KEY is set for any provider -- cannot continue"
    exit /b 1
)

rem -- 2. Cleanup + build once ------------------------------------------------

echo [DEBUG] rmdir leftover src/dist test dirs for %LLM_NAMES%
for %%n in (%LLM_NAMES%) do (
    if exist "%REPO_ROOT%\src\%%n" rmdir /s /q "%REPO_ROOT%\src\%%n"
    if exist "%REPO_ROOT%\dist\%%n" rmdir /s /q "%REPO_ROOT%\dist\%%n"
)
echo [DEBUG] call undeploy.bat (initial cleanup)
call "%REPO_ROOT%\undeploy.bat" >> "%TMP_DIR%\undeploy-initial.log" 2>&1
echo [DEBUG] tear down leftover per-provider projects (ai-md-<llm>) from a prior run
for %%n in (%LLM_NAMES%) do (
    docker compose -p ai-md-%%n down >> "%TMP_DIR%\undeploy-initial.log" 2>&1
)
echo [DEBUG] git checkout -- dist/tetris.ai.md.html dist/convert.ai.md.py
git checkout -- dist/tetris.ai.md.html dist/convert.ai.md.py 2>>"%TMP_DIR%\undeploy-initial.log"
call :record PASS cleanup "prior test artifacts removed, prebuilt dist restored"

echo [DEBUG] call build.bat (docker compose build)
call "%REPO_ROOT%\build.bat" > "%TMP_DIR%\build.log" 2>&1
if errorlevel 1 (
    call :record FAIL build "docker compose build failed -- see %TMP_DIR%\build.log"
    exit /b 1
)
call :record PASS build "docker compose build succeeded"

echo [DEBUG] docker compose config (dump resolved volume paths for debugging)
docker compose config > "%TMP_DIR%\compose-config.log" 2>&1

rem Each provider gets its own docker-compose project (ai-md-<llm>) and its own
rem port, and is left running (not undeployed) so all successful providers are
rem up simultaneously at the end. NEXT_PORT_START tracks where the next
rem provider's port search should begin so ports never collide.
set /a NEXT_PORT_START=18080
set "DEPLOYED_LOG=%TMP_DIR%\deployed-instances.log"
type nul > "%DEPLOYED_LOG%"

echo.
echo ==== dependency checks + build done. Next step calls real LLM APIs. ====
rem DEBUG-PAUSE: remove this block before shipping
pause

rem -- 3. Per-provider verification -------------------------------------------

for %%n in (%LLM_NAMES%) do (
    echo %AVAILABLE_LLMS% | findstr /c:" %%n " >nul
    if not errorlevel 1 call :run_provider %%n
)

echo. >> "%SUMMARY_LOG%"
echo PASS=%PASS_COUNT% FAIL=%FAIL_COUNT% ^(detailed logs: %TMP_DIR%^)
echo PASS=%PASS_COUNT% FAIL=%FAIL_COUNT% ^(detailed logs: %TMP_DIR%^) >> "%SUMMARY_LOG%"

echo.
echo ==== deployed instances (left running; undeploy manually with: docker compose -p ^<project^> down) ====
type "%DEPLOYED_LOG%" 2>nul
echo. >> "%SUMMARY_LOG%"
echo ==== deployed instances ==== >> "%SUMMARY_LOG%"
type "%DEPLOYED_LOG%" 2>nul >> "%SUMMARY_LOG%"

if %FAIL_COUNT% gtr 0 (
    exit /b 1
)
exit /b 0

:check_key
setlocal
set "name=%~1"
set "keyvar=%~2"
call set "val=%%%keyvar%%%"
if not "%val%"=="" (
    endlocal
    set "AVAILABLE_LLMS=%AVAILABLE_LLMS% %1 "
    call :record PASS "api-key:%~1" "%~2 is set"
) else (
    endlocal
    call :record WARN "api-key:%~1" "%~2 not set -- %~1 will be SKIPPED"
)
exit /b 0

:record
rem :record <STATUS> <ITEM> <MESSAGE>
set "status=%~1"
set "item=%~2"
set "msg=%~3"
echo [%status%] %item% %msg%
echo [%status%] %item% %msg% >> "%SUMMARY_LOG%"
if "%status%"=="PASS" set /a PASS_COUNT+=1
if "%status%"=="FAIL" set /a FAIL_COUNT+=1
exit /b 0

:engine_log_since
rem :engine_log_since <marker> -- prints engine log lines after <marker> to stdout
set "marker=%~1"
powershell -NoProfile -Command "docker compose logs engine 2>$null | Select-Object -Skip %marker%"
exit /b 0

:wait_for_mtime_change
rem :wait_for_mtime_change <path> <old_mtime_ticks> <timeout_s> -> sets WAIT_OK=1/0
set "wpath=%~1"
set "wold=%~2"
set "wtimeout=%~3"
powershell -NoProfile -Command ^
  "$deadline=(Get-Date).AddSeconds(%wtimeout%); while((Get-Date) -lt $deadline){ if(Test-Path '%wpath%'){ $m=(Get-Item '%wpath%').LastWriteTime.Ticks; if($m -ne %wold%){ exit 0 } }; Start-Sleep -Seconds 1 }; exit 1"
if errorlevel 1 (set "WAIT_OK=0") else (set "WAIT_OK=1")
exit /b 0

:wait_for_port
rem :wait_for_port <port> <timeout_s> -> sets PORT_OK=1/0 (polls 127.0.0.1:<port> via TCP connect)
set "wport=%~1"
set "wptimeout=%~2"
powershell -NoProfile -Command ^
  "$deadline=(Get-Date).AddSeconds(%wptimeout%); while((Get-Date) -lt $deadline){ try { $c=New-Object System.Net.Sockets.TcpClient; $c.Connect('127.0.0.1', %wport%); $c.Close(); exit 0 } catch { Start-Sleep -Milliseconds 500 } }; exit 1"
if errorlevel 1 (set "PORT_OK=0") else (set "PORT_OK=1")
exit /b 0

:verify_flow_a_spa
rem :verify_flow_a_spa <llm> <spec e.g. tetris.ai.md>
set "llm=%~1"
set "spec=%~2"
set "src_path=%REPO_ROOT%\src\%spec%"
set "dist_path=%REPO_ROOT%\dist\%spec%.html"

echo [DEBUG] curl GET %BASE_URL%/%spec% (hit1, prebuilt)
for /f %%m in ('docker compose logs engine 2^>nul ^| find /c /v ""') do set "mark1=%%m"
for /f "tokens=1,2" %%a in ('curl -s -o "%TMP_DIR%\%llm%-%spec%-hit1.html" -w "%%{http_code} %%{time_total}" "%BASE_URL%/%spec%"') do (set "code1=%%a" & set "t1=%%b")
if "!code1!"=="200" (
    call :record PASS "%llm%:%spec%:prebuilt-hit1" "http=!code1! time=!t1!s"
) else (
    call :record FAIL "%llm%:%spec%:prebuilt-hit1" "http=!code1! time=!t1!s"
)
call :engine_log_since !mark1! > "%TMP_DIR%\_since1.tmp"
findstr /c:"compile start name=%spec%" "%TMP_DIR%\_since1.tmp" >nul
if errorlevel 1 (
    call :record PASS "%llm%:%spec%:prebuilt-no-llm-call" "no compile triggered, served from committed dist/"
) else (
    call :record FAIL "%llm%:%spec%:prebuilt-no-llm-call" "unexpected compile on first hit"
)

echo [DEBUG] touch "%src_path%" to trigger watcher rebuild
for /f %%m in ('powershell -NoProfile -Command "if(Test-Path ''%dist_path%''){(Get-Item ''%dist_path%'').LastWriteTime.Ticks}else{0}"') do set "old_mtime=%%m"
copy /b "%src_path%"+,, "%src_path%" >nul
call :wait_for_mtime_change "%dist_path%" !old_mtime! 30
if "!WAIT_OK!"=="1" (
    call :record PASS "%llm%:%spec%:rebuild-mtime" "dist artifact mtime changed after touch (watcher rebuild)"
) else (
    call :record FAIL "%llm%:%spec%:rebuild-mtime" "dist artifact was not rebuilt within 30s"
)
call :engine_log_since !mark1! > "%TMP_DIR%\_since1.tmp"
findstr /c:"compile ok name=%spec%" "%TMP_DIR%\_since1.tmp" >nul
if not errorlevel 1 (
    call :record PASS "%llm%:%spec%:rebuild-log" "engine log confirms compile ok for %spec%"
) else (
    call :record FAIL "%llm%:%spec%:rebuild-log" "no 'compile ok name=%spec%' found in engine log"
)

echo [DEBUG] curl GET %BASE_URL%/%spec% (hit3, after rebuild settled)
for /f %%m in ('docker compose logs engine 2^>nul ^| find /c /v ""') do set "mark2=%%m"
for /f "tokens=1,2" %%a in ('curl -s -o "%TMP_DIR%\%llm%-%spec%-hit3.html" -w "%%{http_code} %%{time_total}" "%BASE_URL%/%spec%"') do (set "code3=%%a" & set "t3=%%b")
if "!code3!"=="200" (
    call :record PASS "%llm%:%spec%:recache-hit3" "http=!code3! time=!t3!s"
) else (
    call :record FAIL "%llm%:%spec%:recache-hit3" "http=!code3! time=!t3!s"
)
call :engine_log_since !mark2! > "%TMP_DIR%\_since2.tmp"
findstr /c:"compile start name=%spec%" "%TMP_DIR%\_since2.tmp" >nul
if errorlevel 1 (
    call :record PASS "%llm%:%spec%:recache-no-llm-call" "no additional LLM call after rebuild settled"
) else (
    call :record FAIL "%llm%:%spec%:recache-no-llm-call" "unexpected compile on settled re-hit"
)
exit /b 0

:verify_flow_a_api
rem :verify_flow_a_api <llm> <spec e.g. convert.ai.md>
set "llm=%~1"
set "spec=%~2"
set "src_path=%REPO_ROOT%\src\%spec%"
set "dist_path=%REPO_ROOT%\dist\%spec%.py"

echo [DEBUG] curl GET %BASE_URL%/%spec% (hit1, prebuilt api)
for /f %%m in ('docker compose logs engine 2^>nul ^| find /c /v ""') do set "mark1=%%m"
for /f "tokens=1,2" %%a in ('curl -s -o NUL -w "%%{http_code} %%{time_total}" "%BASE_URL%/%spec%"') do (set "code1=%%a" & set "t1=%%b")
if "!code1!"=="302" (
    call :record PASS "%llm%:%spec%:prebuilt-hit1" "http=!code1! time=!t1!s (redirect to /docs)"
) else (
    call :record FAIL "%llm%:%spec%:prebuilt-hit1" "http=!code1! time=!t1!s"
)
call :engine_log_since !mark1! > "%TMP_DIR%\_since1.tmp"
findstr /c:"compile start name=%spec%" "%TMP_DIR%\_since1.tmp" >nul
if errorlevel 1 (
    call :record PASS "%llm%:%spec%:prebuilt-no-llm-call" "no compile triggered, served from committed dist/"
) else (
    call :record FAIL "%llm%:%spec%:prebuilt-no-llm-call" "unexpected compile on first hit"
)

echo [DEBUG] touch "%src_path%" to trigger watcher rebuild
for /f %%m in ('powershell -NoProfile -Command "if(Test-Path ''%dist_path%''){(Get-Item ''%dist_path%'').LastWriteTime.Ticks}else{0}"') do set "old_mtime=%%m"
copy /b "%src_path%"+,, "%src_path%" >nul
call :wait_for_mtime_change "%dist_path%" !old_mtime! 30
if "!WAIT_OK!"=="1" (
    call :record PASS "%llm%:%spec%:rebuild-mtime" "dist artifact mtime changed after touch (watcher rebuild)"
) else (
    call :record FAIL "%llm%:%spec%:rebuild-mtime" "dist artifact was not rebuilt within 30s"
)
call :engine_log_since !mark1! > "%TMP_DIR%\_since1.tmp"
findstr /c:"compile ok name=%spec%" "%TMP_DIR%\_since1.tmp" >nul
if not errorlevel 1 (
    call :record PASS "%llm%:%spec%:rebuild-log" "engine log confirms compile ok for %spec%"
) else (
    call :record FAIL "%llm%:%spec%:rebuild-log" "no 'compile ok name=%spec%' found in engine log"
)

echo [DEBUG] curl GET %BASE_URL%/%spec% (hit3, after rebuild settled, api)
for /f %%m in ('docker compose logs engine 2^>nul ^| find /c /v ""') do set "mark2=%%m"
for /f "tokens=1,2" %%a in ('curl -s -o NUL -w "%%{http_code} %%{time_total}" "%BASE_URL%/%spec%"') do (set "code3=%%a" & set "t3=%%b")
if "!code3!"=="302" (
    call :record PASS "%llm%:%spec%:recache-hit3" "http=!code3! time=!t3!s"
) else (
    call :record FAIL "%llm%:%spec%:recache-hit3" "http=!code3! time=!t3!s"
)
call :engine_log_since !mark2! > "%TMP_DIR%\_since2.tmp"
findstr /c:"compile start name=%spec%" "%TMP_DIR%\_since2.tmp" >nul
if errorlevel 1 (
    call :record PASS "%llm%:%spec%:recache-no-llm-call" "no additional LLM call after rebuild settled"
) else (
    call :record FAIL "%llm%:%spec%:recache-no-llm-call" "unexpected compile on settled re-hit"
)
exit /b 0

:verify_flow_b
rem :verify_flow_b <llm> <relative-spec e.g. sonnet/tetris.ai.md> <expect-code>
set "llm=%~1"
set "spec=%~2"
set "expect_code=%~3"
echo [DEBUG] curl GET %BASE_URL%/%spec% (fresh-generate, real LLM call expected)
for /f %%m in ('docker compose logs engine 2^>nul ^| find /c /v ""') do set "mark=%%m"
for /f "tokens=1,2" %%a in ('curl -s -o "%TMP_DIR%\%llm%-fresh.out" -w "%%{http_code} %%{time_total}" "%BASE_URL%/%spec%"') do (set "code1=%%a" & set "t1=%%b")
if "!code1!"=="!expect_code!" (
    call :record PASS "%llm%:%spec%:fresh-generate" "http=!code1! time=!t1!s"
) else (
    call :record FAIL "%llm%:%spec%:fresh-generate" "http=!code1! time=!t1!s (expected !expect_code!)"
)
call :engine_log_since !mark! > "%TMP_DIR%\_sinceb.tmp"
findstr /c:"llm call start" "%TMP_DIR%\_sinceb.tmp" >nul
if not errorlevel 1 (
    call :record PASS "%llm%:%spec%:llm-invoked" "engine log shows a real LLM call was made"
) else (
    call :record FAIL "%llm%:%spec%:llm-invoked" "no 'llm call start' found in engine log -- LLM was not actually invoked"
)
exit /b 0

:run_provider
set "name=%~1"
set /a "PROV_PASS_START=PASS_COUNT"
set /a "PROV_FAIL_START=FAIL_COUNT"
echo === %name% === >> "%SUMMARY_LOG%"
echo === %name% ===
set "LOGFILE=%TMP_DIR%\%name%-engine.log"

echo [DEBUG] call find-free-port.bat %NEXT_PORT_START% (provider=%name%)
for /f "delims=" %%p in ('call "%REPO_ROOT%\integration-tests\find-free-port.bat" %NEXT_PORT_START%') do set "PORT=%%p"
if "%PORT%"=="" (
    call :record FAIL "%name%:port" "could not find a free port from %NEXT_PORT_START%"
    exit /b 0
)
set "NGINX_PORT=%PORT%"
set "BASE_URL=http://localhost:%PORT%"
set /a "NEXT_PORT_START=PORT+1"
set "COMPOSE_PROJECT_NAME=ai-md-%name%"
call :record PASS "%name%:port" "using NGINX_PORT=%PORT% project=%COMPOSE_PROJECT_NAME%"

echo [DEBUG] CWD before deploy: %CD%
echo [DEBUG] COMPOSE_PROJECT_NAME=%COMPOSE_PROJECT_NAME% NGINX_PORT=%NGINX_PORT%
echo [DEBUG] call deploy-with-%name%.bat
call "%REPO_ROOT%\deploy-with-%name%.bat" > "%TMP_DIR%\%name%-deploy.log" 2>&1
if errorlevel 1 (
    call :record FAIL "%name%:deploy" "deploy-with-%name%.bat failed -- see %TMP_DIR%\%name%-deploy.log"
    exit /b 0
)
echo ai-md-%name%  port=%PORT%  url=%BASE_URL% >> "%DEPLOYED_LOG%"

echo [DEBUG] wait up to 30s for nginx to bind 127.0.0.1:%PORT%
call :wait_for_port %PORT% 30
if "!PORT_OK!"=="1" (
    call :record PASS "%name%:nginx-port" "nginx bound port %PORT% within 30s"
) else (
    call :record FAIL "%name%:nginx-port" "nginx did not bind port %PORT% within 30s -- see %TMP_DIR%\%name%-nginx.log"
    docker compose logs nginx > "%TMP_DIR%\%name%-nginx.log" 2>&1
    docker compose ps > "%TMP_DIR%\%name%-ps.log" 2>&1
    docker compose logs engine > "%LOGFILE%" 2>nul
    exit /b 0
)

echo [DEBUG] docker compose logs nginx ^| findstr ERROR
docker compose logs nginx 2>nul | findstr /i "error" >nul
if not errorlevel 1 (
    call :record FAIL "%name%:nginx-no-errors" "nginx log contains an error after startup"
    docker compose logs nginx > "%TMP_DIR%\%name%-nginx.log" 2>&1
) else (
    call :record PASS "%name%:nginx-no-errors" "no error in nginx log after startup"
)

echo [DEBUG] docker compose logs engine ^| findstr ERROR
docker compose logs engine 2>nul | findstr /i "ERROR" >nul
if not errorlevel 1 (
    call :record FAIL "%name%:no-errors" "engine log contains ERROR after startup"
    docker compose logs engine > "%LOGFILE%" 2>nul
) else (
    call :record PASS "%name%:no-errors" "no ERROR in engine log after startup"
)

echo [DEBUG] call :verify_flow_a_spa %name% tetris.ai.md
call :verify_flow_a_spa %name% tetris.ai.md
echo [DEBUG] call :verify_flow_a_api %name% convert.ai.md
call :verify_flow_a_api %name% convert.ai.md

echo [DEBUG] mkdir src\%name% + copy specs for fresh-generate flow
mkdir "%REPO_ROOT%\src\%name%" >nul 2>&1
copy /y "%REPO_ROOT%\src\tetris.ai.md" "%REPO_ROOT%\src\%name%\tetris.ai.md" >nul
copy /y "%REPO_ROOT%\src\convert.ai.md" "%REPO_ROOT%\src\%name%\convert.ai.md" >nul
echo [DEBUG] call :verify_flow_b %name% %name%/tetris.ai.md 200
call :verify_flow_b %name% %name%/tetris.ai.md 200
echo [DEBUG] call :verify_flow_b %name% %name%/convert.ai.md 302
call :verify_flow_b %name% %name%/convert.ai.md 302

echo [DEBUG] docker compose logs engine ^> logfile
docker compose logs engine > "%LOGFILE%" 2>nul

set /a "PROV_PASS=PASS_COUNT-PROV_PASS_START"
set /a "PROV_FAIL=FAIL_COUNT-PROV_FAIL_START"
echo.
echo ==== %name% test done: PASS=%PROV_PASS% FAIL=%PROV_FAIL% ====
rem DEBUG-PAUSE: remove this block before shipping
pause

rem Intentionally NOT undeployed: this provider's stack (ai-md-%name% on
rem port %PORT%) is left running so all successful providers accumulate and
rem are all reachable at once once the full run finishes.
rem src/%name% and dist/%name% are intentionally kept for post-run inspection.
exit /b 0
