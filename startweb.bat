@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-common.ps1" -Mode web
if errorlevel 1 (
    echo.
    echo [ERROR] Web startup failed.
    pause
    exit /b 1
)

echo.
echo Web startup completed.
pause
