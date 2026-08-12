@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-common.ps1" -Mode all
if errorlevel 1 (
    echo.
    echo [ERROR] Web and mobile startup failed.
    pause
    exit /b 1
)

echo.
echo Web and mobile startup completed.
pause
