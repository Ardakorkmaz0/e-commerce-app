@echo off
setlocal
cd /d "%~dp0"

REM Starts PostgreSQL and Django only. Run the Flutter app from Android
REM Studio afterwards, so the two do not fight over the emulator.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-common.ps1" -Mode backend
if errorlevel 1 (
    echo.
    echo [ERROR] Backend startup failed.
    pause
    exit /b 1
)

echo.
echo Backend is running. Start the mobile app from Android Studio.
pause
