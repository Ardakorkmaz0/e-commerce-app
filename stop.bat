@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\stop-all.ps1"
if errorlevel 1 (
    echo.
    echo [ERROR] One or more project services could not be stopped.
    pause
    exit /b 1
)

echo.
echo All project services are stopped. PostgreSQL data was preserved.
pause
