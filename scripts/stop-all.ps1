$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeDirectory = Join-Path $projectRoot ".runtime"

function Invoke-NativeQuietly {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $FilePath @Arguments *> $null
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorPreference
    }
}

function Stop-ManagedProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $pidFile = Join-Path $runtimeDirectory "$Name.pid"
    if (-not (Test-Path -LiteralPath $pidFile)) {
        Write-Host "$Name is already stopped."
        return
    }

    $pidData = @(Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue)
    $processId = $pidData | Select-Object -First 1
    $expectedStartTicks = if ($pidData.Count -gt 1) { [long]$pidData[1] } else { $null }
    $process = if ($processId) {
        Get-Process -Id $processId -ErrorAction SilentlyContinue
    }
    $processRecord = if ($processId) {
        Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
    }

    $expectedPatterns = switch ($Name) {
        "django" { @("manage.py", "runserver") }
        "next" { @("npm.cmd", "run dev") }
        "flutter" { @("flutter.bat", "run") }
    }

    if (
        $processRecord -and
        $process -and
        (
            -not $expectedStartTicks -or
            $process.StartTime.ToUniversalTime().Ticks -eq $expectedStartTicks
        ) -and
        $processRecord.CommandLine -and
        -not ($expectedPatterns | Where-Object {
            $processRecord.CommandLine.IndexOf(
                $_,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -lt 0
        })
    ) {
        & taskkill.exe /PID $processId /T /F *> $null
        Write-Host "$Name stopped. PID: $processId"
    }
    elseif ($processRecord) {
        Write-Host "$Name PID file is stale; the unrelated process was not stopped."
    }
    else {
        Write-Host "$Name is already stopped."
    }

    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}

Stop-ManagedProcess -Name "flutter"
Stop-ManagedProcess -Name "next"
Stop-ManagedProcess -Name "django"

$androidDeviceIdFile = Join-Path $runtimeDirectory "android-device.id"
$adbCandidates = @((Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"))
$adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
$adbExecutable = if ($adbCommand) {
    $adbCommand.Source
}
else {
    $adbCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if ((Test-Path -LiteralPath $androidDeviceIdFile) -and $adbExecutable) {
    $androidDeviceId = Get-Content -LiteralPath $androidDeviceIdFile -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($androidDeviceId) {
        $previousErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & $adbExecutable -s $androidDeviceId reverse --remove tcp:8000 *> $null
        $ErrorActionPreference = $previousErrorPreference
    }
    Remove-Item -LiteralPath $androidDeviceIdFile -Force -ErrorAction SilentlyContinue
}

$emulatorIdFile = Join-Path $runtimeDirectory "emulator.id"
if (Test-Path -LiteralPath $emulatorIdFile) {
    $emulatorId = Get-Content -LiteralPath $emulatorIdFile -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($emulatorId -and $adbExecutable) {
        $previousErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & $adbExecutable -s $emulatorId emu kill *> $null
        $emulatorStopExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorPreference
        if ($emulatorStopExitCode -eq 0) {
            Write-Host "Android emulator stopped: $emulatorId"
        }
        else {
            Write-Host "Android emulator is already stopped."
        }
    }

    Remove-Item -LiteralPath $emulatorIdFile -Force -ErrorAction SilentlyContinue
}

$dockerCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\DockerDesktop\resources\bin\docker.exe"),
    (Join-Path $env:ProgramFiles "Docker\Docker\resources\bin\docker.exe")
)
$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
$dockerExecutable = if ($dockerCommand) {
    $dockerCommand.Source
}
else {
    $dockerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if ($dockerExecutable) {
    $dockerInfoExitCode = Invoke-NativeQuietly -FilePath $dockerExecutable -Arguments @("info")
    if ($dockerInfoExitCode -eq 0) {
        Push-Location $projectRoot
        try {
            & $dockerExecutable compose stop
            if ($LASTEXITCODE -ne 0) {
                throw "Docker services could not be stopped."
            }
        }
        finally {
            Pop-Location
        }
        Write-Host "Docker services stopped."
    }
    else {
        Write-Host "Docker Desktop is already stopped."
    }
}
else {
    Write-Host "Docker was not found; container services could not be checked."
}

if (Test-Path -LiteralPath $runtimeDirectory) {
    Get-ChildItem -LiteralPath $runtimeDirectory -Filter "*.pid" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
