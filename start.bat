@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "PROJECT_ROOT=%~dp0"
set "PROJECT_RUNTIME=%~dp0.runtime"
set "PROJECT_PYTHON=%~dp0venv\Scripts\python.exe"
set "DJANGO_PID_FILE=%~dp0.runtime\django.pid"
set "DOCKER_EXE="

where docker >nul 2>&1
if not errorlevel 1 set "DOCKER_EXE=docker"
if not defined DOCKER_EXE if exist "%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin\docker.exe" set "DOCKER_EXE=%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin\docker.exe"
if not defined DOCKER_EXE if exist "%ProgramFiles%\Docker\Docker\resources\bin\docker.exe" set "DOCKER_EXE=%ProgramFiles%\Docker\Docker\resources\bin\docker.exe"

if not defined DOCKER_EXE (
    echo [ERROR] Docker command was not found.
    echo Open Docker Desktop and run this file again.
    pause
    exit /b 1
)

"%DOCKER_EXE%" info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Desktop is not running.
    echo Start Docker Desktop and wait until it is fully ready.
    pause
    exit /b 1
)

if not exist "%PROJECT_PYTHON%" (
    echo [ERROR] Python virtual environment was not found:
    echo %PROJECT_PYTHON%
    pause
    exit /b 1
)

if not exist "%PROJECT_RUNTIME%" mkdir "%PROJECT_RUNTIME%"

"%DOCKER_EXE%" compose config --quiet
if errorlevel 1 (
    echo [ERROR] compose.yaml or .env configuration is invalid.
    pause
    exit /b 1
)

echo Starting Docker services...
"%DOCKER_EXE%" compose up -d --wait --wait-timeout 60
if errorlevel 1 (
    echo [ERROR] Docker services could not be started.
    pause
    exit /b 1
)

"%DOCKER_EXE%" compose ps

set "DJANGO_ALREADY_RUNNING=0"
if exist "%DJANGO_PID_FILE%" (
    set /p "DJANGO_PID="<"%DJANGO_PID_FILE%"
    if defined DJANGO_PID (
        tasklist /FI "PID eq !DJANGO_PID!" /NH 2>nul | findstr /R /C:"[ ]!DJANGO_PID![ ]" >nul
        if not errorlevel 1 set "DJANGO_ALREADY_RUNNING=1"
    )
)

if "!DJANGO_ALREADY_RUNNING!"=="1" (
    echo Django is already running. PID: !DJANGO_PID!
) else (
    if exist "%DJANGO_PID_FILE%" del /q "%DJANGO_PID_FILE%"
    echo Running Django system checks...
    "%PROJECT_PYTHON%" manage.py check
    if errorlevel 1 (
        echo [ERROR] Django system check failed.
        pause
        exit /b 1
    )

    echo Starting Django...

    for /f "usebackq delims=" %%P in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p = Start-Process -FilePath $env:PROJECT_PYTHON -ArgumentList 'manage.py','runserver','127.0.0.1:8000' -WorkingDirectory $env:PROJECT_ROOT -WindowStyle Hidden -PassThru; $p.Id"`) do set "DJANGO_PID=%%P"

    if not defined DJANGO_PID (
        echo [ERROR] Django process could not be started.
        pause
        exit /b 1
    )

    >"%DJANGO_PID_FILE%" echo !DJANGO_PID!
    timeout /t 2 /nobreak >nul

    tasklist /FI "PID eq !DJANGO_PID!" /NH 2>nul | findstr /R /C:"[ ]!DJANGO_PID![ ]" >nul
    if errorlevel 1 (
        echo [ERROR] Django exited immediately after startup.
        echo Run python manage.py runserver in the virtual environment to see the error.
        del /q "%DJANGO_PID_FILE%" >nul 2>&1
        pause
        exit /b 1
    )

    echo Django started. PID: !DJANGO_PID!
)

echo.
echo Project is ready: http://127.0.0.1:8000/
pause
