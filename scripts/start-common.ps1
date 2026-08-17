param(
    # "backend" starts PostgreSQL and Django only, leaving the Flutter app to
    # be launched from Android Studio. Running both fights over the emulator.
    [Parameter(Mandatory = $true)]
    [ValidateSet("backend", "web", "mobile", "all")]
    [string]$Mode
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeDirectory = Join-Path $projectRoot ".runtime"
$pythonExecutable = Join-Path $projectRoot "venv\Scripts\python.exe"
$webDirectory = Join-Path $projectRoot "web"
$mobileDirectory = Join-Path $projectRoot "mobile"

New-Item -ItemType Directory -Force -Path $runtimeDirectory | Out-Null

function Resolve-CommandPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string[]]$Candidates = @()
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw "$Name was not found."
}

function Test-ManagedProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PidFile,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $PidFile)) {
        return $false
    }

    $pidData = @(Get-Content -LiteralPath $PidFile -ErrorAction SilentlyContinue)
    $processId = $pidData | Select-Object -First 1
    $expectedStartTicks = if ($pidData.Count -gt 1) { [long]$pidData[1] } else { $null }
    if (-not $processId) {
        Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
        return $false
    }

    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    $processRecord = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
    $startTimeMatches = $process -and (
        -not $expectedStartTicks -or
        $process.StartTime.ToUniversalTime().Ticks -eq $expectedStartTicks
    )
    if ($processRecord -and $startTimeMatches) {
        $expectedPatterns = switch ($Name) {
            "django" { @("manage.py", "runserver") }
            "next" { @("npm.cmd", "run dev") }
            "flutter" { @("flutter.bat", "run") }
        }

        if (
            $processRecord.CommandLine -and
            -not ($expectedPatterns | Where-Object {
                $processRecord.CommandLine.IndexOf(
                    $_,
                    [System.StringComparison]::OrdinalIgnoreCase
                ) -lt 0
            })
        ) {
            return $true
        }
    }

    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    return $false
}

function Get-ManagedProcessRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PidFile,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $PidFile)) {
        return $null
    }

    $pidData = @(Get-Content -LiteralPath $PidFile -ErrorAction SilentlyContinue)
    $processId = $pidData | Select-Object -First 1
    $expectedStartTicks = if ($pidData.Count -gt 1) { [long]$pidData[1] } else { $null }
    if (-not $processId) {
        return $null
    }

    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    $processRecord = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
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
        return $processRecord
    }

    return $null
}

function Wait-ForTcpPort {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port,
        [Parameter(Mandatory = $true)]
        [string]$ProcessName,
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds
    )

    $pidFile = Join-Path $runtimeDirectory "$ProcessName.pid"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $processRecord = Get-ManagedProcessRecord -PidFile $pidFile -Name $ProcessName
        if (-not $processRecord) {
            throw "$ProcessName exited before port $Port became ready."
        }

        $connection = Test-NetConnection -ComputerName "127.0.0.1" -Port $Port -WarningAction SilentlyContinue
        if ($connection.TcpTestSucceeded) {
            return
        }

        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    throw "$ProcessName did not open port $Port within $TimeoutSeconds seconds."
}

function Wait-ForFlutterReady {
    param(
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds
    )

    $pidFile = Join-Path $runtimeDirectory "flutter.pid"
    $logFile = Join-Path $runtimeDirectory "flutter.log"
    $errorLogFile = Join-Path $runtimeDirectory "flutter.error.log"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    do {
        $processRecord = Get-ManagedProcessRecord -PidFile $pidFile -Name "flutter"
        $logOutput = Get-Content -LiteralPath $logFile -Raw -ErrorAction SilentlyContinue

        if ($logOutput -match "Flutter run key commands|A Dart VM Service") {
            return
        }

        if (-not $processRecord) {
            $errorOutput = Get-Content -LiteralPath $errorLogFile -Raw -ErrorAction SilentlyContinue
            if ($logOutput) {
                Write-Host $logOutput
            }
            if ($errorOutput) {
                Write-Host $errorOutput
            }
            throw "Flutter exited before the application became ready."
        }

        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)

    throw "Flutter did not become ready within $TimeoutSeconds seconds."
}

function Start-ManagedProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    $pidFile = Join-Path $runtimeDirectory "$Name.pid"
    if (Test-ManagedProcess -PidFile $pidFile -Name $Name) {
        $existingProcessId = Get-Content -LiteralPath $pidFile | Select-Object -First 1
        Write-Host "$Name is already running. PID: $existingProcessId"
        return $false
    }

    $standardOutput = Join-Path $runtimeDirectory "$Name.log"
    $standardError = Join-Path $runtimeDirectory "$Name.error.log"
    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -WorkingDirectory $WorkingDirectory `
        -RedirectStandardOutput $standardOutput `
        -RedirectStandardError $standardError `
        -WindowStyle Hidden `
        -PassThru

    Start-Sleep -Milliseconds 1200
    if ($process.HasExited) {
        $errorOutput = Get-Content -LiteralPath $standardError -Raw -ErrorAction SilentlyContinue
        if ($errorOutput) {
            Write-Host $errorOutput
        }
        throw "$Name exited during startup. Check $standardError."
    }

    Set-Content `
        -LiteralPath $pidFile `
        -Value @($process.Id, $process.StartTime.ToUniversalTime().Ticks) `
        -Encoding ascii
    Write-Host "$Name started. PID: $($process.Id)"
    return $true
}

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

$dockerExecutable = Resolve-CommandPath `
    -Name "docker" `
    -Candidates @(
        (Join-Path $env:LOCALAPPDATA "Programs\DockerDesktop\resources\bin\docker.exe"),
        (Join-Path $env:ProgramFiles "Docker\Docker\resources\bin\docker.exe")
    )

$dockerInfoExitCode = Invoke-NativeQuietly -FilePath $dockerExecutable -Arguments @("info")
if ($dockerInfoExitCode -ne 0) {
    Write-Host "Starting Docker Desktop..."
    $dockerStartExitCode = Invoke-NativeQuietly `
        -FilePath $dockerExecutable `
        -Arguments @("desktop", "start")
    if ($dockerStartExitCode -ne 0) {
        throw "Docker Desktop could not be started."
    }

    $dockerDeadline = (Get-Date).AddMinutes(2)
    do {
        Start-Sleep -Seconds 2
        $dockerInfoExitCode = Invoke-NativeQuietly -FilePath $dockerExecutable -Arguments @("info")
        $dockerReady = $dockerInfoExitCode -eq 0
    } while (-not $dockerReady -and (Get-Date) -lt $dockerDeadline)

    if (-not $dockerReady) {
        throw "Docker Desktop did not become ready within two minutes."
    }
}

if (-not (Test-Path -LiteralPath $pythonExecutable)) {
    throw "Python virtual environment was not found at $pythonExecutable."
}

Push-Location $projectRoot
try {
    & $dockerExecutable compose config --quiet
    if ($LASTEXITCODE -ne 0) {
        throw "compose.yaml or .env configuration is invalid."
    }

    & $dockerExecutable compose up -d --wait --wait-timeout 60 db
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL could not be started."
    }
}
finally {
    Pop-Location
}

& $pythonExecutable manage.py check
if ($LASTEXITCODE -ne 0) {
    throw "Django system checks failed."
}

$djangoStarted = Start-ManagedProcess `
    -Name "django" `
    -FilePath $pythonExecutable `
    -ArgumentList @("manage.py", "runserver", "127.0.0.1:8000") `
    -WorkingDirectory $projectRoot
if ($djangoStarted) {
    Wait-ForTcpPort -Port 8000 -ProcessName "django" -TimeoutSeconds 30
}

if ($Mode -in @("web", "all")) {
    $npmExecutable = Resolve-CommandPath `
        -Name "npm.cmd" `
        -Candidates @((Join-Path $env:ProgramFiles "nodejs\npm.cmd"))

    if (-not (Test-Path -LiteralPath (Join-Path $webDirectory "node_modules"))) {
        throw "Web dependencies were not found. Run npm install in the web directory."
    }

    $nextStarted = Start-ManagedProcess `
        -Name "next" `
        -FilePath $npmExecutable `
        -ArgumentList @("run", "dev", "--", "--hostname", "127.0.0.1", "--port", "3000") `
        -WorkingDirectory $webDirectory
    if ($nextStarted) {
        Wait-ForTcpPort -Port 3000 -ProcessName "next" -TimeoutSeconds 45
    }
}

if ($Mode -in @("mobile", "all")) {
    $flutterExecutable = Resolve-CommandPath `
        -Name "flutter.bat" `
        -Candidates @((Join-Path $env:USERPROFILE "develop\flutter\bin\flutter.bat"))
    $adbExecutable = Resolve-CommandPath `
        -Name "adb.exe" `
        -Candidates @((Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"))

    $connectedDevices = & $flutterExecutable devices --machine 2>$null | ConvertFrom-Json
    $androidDevice = $connectedDevices | Where-Object { $_.targetPlatform -like "android-*" } | Select-Object -First 1

    if (-not $androidDevice) {
        Write-Host "Launching the Pixel_8 emulator..."
        & $flutterExecutable emulators --launch Pixel_8
        if ($LASTEXITCODE -ne 0) {
            throw "The Pixel_8 emulator could not be launched."
        }

        $deadline = (Get-Date).AddMinutes(3)
        do {
            Start-Sleep -Seconds 2
            $connectedDevices = & $flutterExecutable devices --machine 2>$null | ConvertFrom-Json
            $androidDevice = $connectedDevices |
                Where-Object { $_.targetPlatform -like "android-*" } |
                Select-Object -First 1
            $bootCompleted = if ($androidDevice) {
                (& $adbExecutable -s $androidDevice.id shell getprop sys.boot_completed 2>$null | Out-String).Trim()
            }
            else {
                ""
            }
        } while ($bootCompleted -ne "1" -and (Get-Date) -lt $deadline)

        if ($bootCompleted -ne "1") {
            throw "The Android emulator did not finish booting within three minutes."
        }

        if ($androidDevice) {
            Set-Content `
                -LiteralPath (Join-Path $runtimeDirectory "emulator.id") `
                -Value $androidDevice.id `
                -Encoding ascii
        }
    }

    if (-not $androidDevice) {
        throw "No Android device is available."
    }

    & $adbExecutable -s $androidDevice.id reverse tcp:8000 tcp:8000 *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "ADB reverse for the backend port could not be configured."
    }

    Set-Content `
        -LiteralPath (Join-Path $runtimeDirectory "android-device.id") `
        -Value $androidDevice.id `
        -Encoding ascii

    $null = Start-ManagedProcess `
        -Name "flutter" `
        -FilePath $flutterExecutable `
        -ArgumentList @("run", "-d", $androidDevice.id, "--dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1/") `
        -WorkingDirectory $mobileDirectory
    Wait-ForFlutterReady -TimeoutSeconds 180
}

Write-Host ""
Write-Host "Backend API: http://127.0.0.1:8000/api/v1/"
Write-Host "Django Admin: http://127.0.0.1:8000/admin/"
if ($Mode -in @("web", "all")) {
    Write-Host "Web application: http://localhost:3000/"
}
if ($Mode -in @("mobile", "all")) {
    Write-Host "Mobile application started on $($androidDevice.name)."
}
