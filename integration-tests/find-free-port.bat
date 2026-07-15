@echo off
setlocal
set "START=%~1"
if "%START%"=="" set "START=18080"

for /f "usebackq delims=" %%p in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0find-free-port.ps1" -Start %START%`) do set "PORT=%%p"

if "%PORT%"=="" (
    echo no free port found starting at %START% 1>&2
    exit /b 1
)

echo %PORT%
exit /b 0
