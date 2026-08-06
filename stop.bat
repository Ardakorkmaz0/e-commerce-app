@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "DJANGO_PID_FILE=%~dp0.runtime\django.pid"
set "DOCKER_EXE="

if exist "%DJANGO_PID_FILE%" (
    set /p "DJANGO_PID="<"%DJANGO_PID_FILE%"
    if defined DJANGO_PID (
        tasklist /FI "PID eq !DJANGO_PID!" /NH 2>nul | findstr /R /C:"[ ]!DJANGO_PID![ ]" >nul
        if not errorlevel 1 (
            echo Stopping Django. PID: !DJANGO_PID!
            taskkill /PID !DJANGO_PID! /T /F >nul 2>&1
        ) else (
            echo Django is already stopped.
        )
    )
    del /q "%DJANGO_PID_FILE%" >nul 2>&1
) else (
    echo Django PID file was not found; Django may already be stopped.
)

where docker >nul 2>&1
if not errorlevel 1 set "DOCKER_EXE=docker"
if not defined DOCKER_EXE if exist "%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin\docker.exe" set "DOCKER_EXE=%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin\docker.exe"
if not defined DOCKER_EXE if exist "%ProgramFiles%\Docker\Docker\resources\bin\docker.exe" set "DOCKER_EXE=%ProgramFiles%\Docker\Docker\resources\bin\docker.exe"

if not defined DOCKER_EXE (
    echo Docker command was not found; Docker services could not be checked.
    pause
    exit /b 0
)

"%DOCKER_EXE%" info >nul 2>&1
if errorlevel 1 (
    echo Docker Desktop is already closed; container services are not running.
    pause
    exit /b 0
)

echo Stopping this project's Docker services...
"%DOCKER_EXE%" compose stop
if errorlevel 1 (
    echo [ERROR] One or more Docker services could not be stopped.
    pause
    exit /b 1
)

"%DOCKER_EXE%" compose ps
echo.
echo Project stopped. Containers and the database volume were preserved.
pause
