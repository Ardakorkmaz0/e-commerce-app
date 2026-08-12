@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-common.ps1" -Mode mobile
if errorlevel 1 (
    echo.
    echo [ERROR] Mobile startup failed.
    pause
    exit /b 1
)

echo.
echo Mobile startup completed.
pause
