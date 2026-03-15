#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NL2Bot service manager — install/start/stop/restart Planning + Simulation servers as Windows services.
.USAGE
    .\services.ps1 install|uninstall|start|stop|restart|status|logs
#>

param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet("install", "uninstall", "start", "stop", "restart", "status", "logs")]
    [string]$Action
)

$BackupTaskName = "NL2Bot-DailyBackup"

$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Users\ahnch\Documents\ROBOT4KID"
$LogDir = "$ProjectRoot\logs"
$EnvFile = "$ProjectRoot\.env"

$CloudflaredExe = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Cloudflare.cloudflared_Microsoft.Winget.Source_8wekyb3d8bbwe\cloudflared.exe"
$CloudflaredConfig = "$env:USERPROFILE\.cloudflared\config.yml"

$Services = @(
    @{
        Name        = "NL2Bot-Planning"
        DisplayName = "NL2Bot Planning Server"
        Description = "NL2Bot Planning Server (FastAPI, port 8000)"
        Python      = "$ProjectRoot\planning_server\.venv\Scripts\python.exe"
        Args        = "-m uvicorn planning_server.app.main:app --host 0.0.0.0 --port 8000"
        LogPrefix   = "planning"
    },
    @{
        Name        = "NL2Bot-Simulation"
        DisplayName = "NL2Bot Simulation Server"
        Description = "NL2Bot Simulation Server (FastAPI, port 8100)"
        Python      = "$ProjectRoot\simulation_server\.venv\Scripts\python.exe"
        Args        = "-m uvicorn simulation_server.app.main:app --host 0.0.0.0 --port 8100"
        LogPrefix   = "simulation"
    }
)

# Cloudflare tunnel service (separate from Python services)
$TunnelService = @{
    Name        = "NL2Bot-Tunnel"
    DisplayName = "NL2Bot Cloudflare Tunnel"
    Description = "Cloudflare Tunnel for NL2Bot external HTTPS access"
    Executable  = $CloudflaredExe
    Args        = "tunnel --config $CloudflaredConfig run"
    LogPrefix   = "tunnel"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Parse-EnvFile {
    <#
    .SYNOPSIS
        Read a .env file and return an array of KEY=VALUE strings,
        skipping blanks and comments.
    #>
    if (-not (Test-Path $EnvFile)) {
        Write-Warning ".env file not found at $EnvFile — services will run without extra env vars."
        return @()
    }

    $envVars = @()
    foreach ($line in Get-Content $EnvFile) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        # Strip surrounding quotes from values (KEY="value" -> KEY=value)
        if ($trimmed -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim().Trim('"').Trim("'")
            $envVars += "$key=$val"
        }
    }
    return $envVars
}

$NssmExe = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\NSSM.NSSM_Microsoft.Winget.Source_8wekyb3d8bbwe\nssm-2.24-101-g897c7ad\win64\nssm.exe"

function Ensure-NssmAvailable {
    if (-not (Test-Path $NssmExe)) {
        # Fallback to PATH
        if (Get-Command nssm -ErrorAction SilentlyContinue) {
            $script:NssmExe = (Get-Command nssm).Source
        } else {
            Write-Error "NSSM not found. Install it with: winget install nssm"
            exit 1
        }
    }
    Set-Alias -Name nssm -Value $NssmExe -Scope Script
}

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

function Do-Install {
    Ensure-NssmAvailable

    # Create logs directory
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        Write-Host "Created log directory: $LogDir"
    }

    # Parse environment variables from .env
    $envVars = Parse-EnvFile

    foreach ($svc in $Services) {
        $name = $svc.Name

        # Check if already installed
        $existing = nssm status $name 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Warning "Service '$name' is already installed (status: $existing). Skipping."
            continue
        }

        Write-Host "Installing service: $name ..." -ForegroundColor Cyan

        # Install the service
        nssm install $name $svc.Python
        if ($LASTEXITCODE -ne 0) { Write-Error "Failed to install $name"; return }

        # Application parameters (uvicorn args)
        nssm set $name AppParameters $svc.Args

        # Working directory
        nssm set $name AppDirectory $ProjectRoot

        # Display name and description
        nssm set $name DisplayName $svc.DisplayName
        nssm set $name Description $svc.Description

        # Auto-start on boot
        nssm set $name Start SERVICE_AUTO_START

        # Stdout and stderr log files
        $stdoutLog = "$LogDir\$($svc.LogPrefix)_stdout.log"
        $stderrLog = "$LogDir\$($svc.LogPrefix)_stderr.log"

        nssm set $name AppStdout $stdoutLog
        nssm set $name AppStderr $stderrLog

        # Append to log files (don't truncate on restart)
        nssm set $name AppStdoutCreationDisposition 4
        nssm set $name AppStderrCreationDisposition 4

        # Rotate logs: enable file rotation
        nssm set $name AppRotateFiles 1
        nssm set $name AppRotateOnline 1
        # Rotate when log exceeds 10 MB
        nssm set $name AppRotateBytes 10485760

        # Environment variables from .env
        if ($envVars.Count -gt 0) {
            nssm set $name AppEnvironmentExtra $envVars
        }

        Write-Host "  Installed $name" -ForegroundColor Green
        Write-Host "    Executable : $($svc.Python)"
        Write-Host "    Parameters : $($svc.Args)"
        Write-Host "    WorkDir    : $ProjectRoot"
        Write-Host "    Stdout log : $stdoutLog"
        Write-Host "    Stderr log : $stderrLog"
    }

    # Install tunnel service
    $ts = $TunnelService
    $tsName = $ts.Name
    $tsExisting = nssm status $tsName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "Service '$tsName' is already installed (status: $tsExisting). Skipping."
    } elseif (Test-Path $ts.Executable) {
        Write-Host "Installing service: $tsName ..." -ForegroundColor Cyan
        nssm install $tsName $ts.Executable
        nssm set $tsName AppParameters $ts.Args
        nssm set $tsName AppDirectory $ProjectRoot
        nssm set $tsName DisplayName $ts.DisplayName
        nssm set $tsName Description $ts.Description
        nssm set $tsName Start SERVICE_AUTO_START
        nssm set $tsName AppStdout "$LogDir\$($ts.LogPrefix)_stdout.log"
        nssm set $tsName AppStderr "$LogDir\$($ts.LogPrefix)_stderr.log"
        nssm set $tsName AppStdoutCreationDisposition 4
        nssm set $tsName AppStderrCreationDisposition 4
        nssm set $tsName AppRotateFiles 1
        nssm set $tsName AppRotateOnline 1
        nssm set $tsName AppRotateBytes 10485760
        Write-Host "  Installed $tsName" -ForegroundColor Green
        Write-Host "    Executable : $($ts.Executable)"
        Write-Host "    Parameters : $($ts.Args)"
    } else {
        Write-Warning "cloudflared not found at $($ts.Executable). Skipping tunnel service."
    }

    # Install daily backup scheduled task
    Write-Host "Installing scheduled task: $BackupTaskName ..." -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ProjectRoot\system\daily_backup.ps1" -Register
    Write-Host ""

    Write-Host "`nAll services installed. Run '.\services.ps1 start' to start them." -ForegroundColor Green
}

function Do-Uninstall {
    Ensure-NssmAvailable

    $allServices = $Services + @($TunnelService)
    foreach ($svc in $allServices) {
        $name = $svc.Name

        # Try to stop first
        Write-Host "Stopping service: $name ..." -ForegroundColor Yellow
        nssm stop $name 2>&1 | Out-Null

        Write-Host "Removing service: $name ..." -ForegroundColor Cyan
        nssm remove $name confirm
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Removed $name" -ForegroundColor Green
        } else {
            Write-Warning "  Could not remove $name (may not be installed)."
        }
    }

    # Remove daily backup scheduled task
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ProjectRoot\system\daily_backup.ps1" -Unregister

    Write-Host "`nAll services removed." -ForegroundColor Green
}

function Do-Start {
    Ensure-NssmAvailable

    $allServices = $Services + @($TunnelService)
    foreach ($svc in $allServices) {
        $name = $svc.Name
        Write-Host "Starting service: $name ..." -ForegroundColor Cyan
        nssm start $name
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Started $name" -ForegroundColor Green
        } else {
            Write-Warning "  Failed to start $name. Check logs with: .\services.ps1 logs"
        }
    }
}

function Do-Stop {
    Ensure-NssmAvailable

    $allServices = $Services + @($TunnelService)
    foreach ($svc in $allServices) {
        $name = $svc.Name
        Write-Host "Stopping service: $name ..." -ForegroundColor Yellow
        nssm stop $name
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Stopped $name" -ForegroundColor Green
        } else {
            Write-Warning "  Failed to stop $name (may not be running)."
        }
    }
}

function Do-Restart {
    Ensure-NssmAvailable

    $allServices = $Services + @($TunnelService)
    foreach ($svc in $allServices) {
        $name = $svc.Name
        Write-Host "Restarting service: $name ..." -ForegroundColor Cyan
        nssm restart $name
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Restarted $name" -ForegroundColor Green
        } else {
            Write-Warning "  Failed to restart $name."
        }
    }
}

function Do-Status {
    Ensure-NssmAvailable

    Write-Host "`nNL2Bot Service Status" -ForegroundColor Cyan
    Write-Host ("-" * 50)

    $allServices = $Services + @($TunnelService)
    foreach ($svc in $allServices) {
        $name = $svc.Name
        $status = nssm status $name 2>&1
        if ($LASTEXITCODE -ne 0) {
            $status = "NOT INSTALLED"
        }

        $color = switch ($status) {
            "SERVICE_RUNNING"  { "Green" }
            "SERVICE_STOPPED"  { "Yellow" }
            "SERVICE_PAUSED"   { "Yellow" }
            "NOT INSTALLED"    { "Red" }
            default            { "White" }
        }

        Write-Host ("  {0,-25} {1}" -f $name, $status) -ForegroundColor $color
    }

    # Backup scheduled task status
    $backupTask = Get-ScheduledTask -TaskName $BackupTaskName -ErrorAction SilentlyContinue
    if ($backupTask) {
        $backupInfo = Get-ScheduledTaskInfo -TaskName $BackupTaskName
        $backupState = $backupTask.State
        $bColor = if ($backupState -eq "Ready") { "Green" } else { "Yellow" }
        Write-Host ("  {0,-25} {1}" -f $BackupTaskName, $backupState) -ForegroundColor $bColor
        if ($backupInfo.LastRunTime -and $backupInfo.LastRunTime.Year -gt 2000) {
            Write-Host ("  {0,-25} Last: {1}" -f "", $backupInfo.LastRunTime) -ForegroundColor DarkGray
        }
        if ($backupInfo.NextRunTime) {
            Write-Host ("  {0,-25} Next: {1}" -f "", $backupInfo.NextRunTime) -ForegroundColor DarkGray
        }
    } else {
        Write-Host ("  {0,-25} {1}" -f $BackupTaskName, "NOT REGISTERED") -ForegroundColor Red
    }

    Write-Host ""
}

function Do-Logs {
    Write-Host "`nNL2Bot Log Files" -ForegroundColor Cyan
    Write-Host ("-" * 50)

    $allServices = $Services + @($TunnelService)
    foreach ($svc in $allServices) {
        $stdoutLog = "$LogDir\$($svc.LogPrefix)_stdout.log"
        $stderrLog = "$LogDir\$($svc.LogPrefix)_stderr.log"

        Write-Host "`n  $($svc.Name):" -ForegroundColor White

        if (Test-Path $stdoutLog) {
            $size = [math]::Round((Get-Item $stdoutLog).Length / 1KB, 1)
            Write-Host "    stdout: $stdoutLog ($size KB)"
        } else {
            Write-Host "    stdout: $stdoutLog (not yet created)" -ForegroundColor DarkGray
        }

        if (Test-Path $stderrLog) {
            $size = [math]::Round((Get-Item $stderrLog).Length / 1KB, 1)
            Write-Host "    stderr: $stderrLog ($size KB)"
        } else {
            Write-Host "    stderr: $stderrLog (not yet created)" -ForegroundColor DarkGray
        }
    }

    # Backup log
    Write-Host "`n  $BackupTaskName`:" -ForegroundColor White
    $backupLog = "$LogDir\backup.log"
    if (Test-Path $backupLog) {
        $size = [math]::Round((Get-Item $backupLog).Length / 1KB, 1)
        Write-Host "    log   : $backupLog ($size KB)"
    } else {
        Write-Host "    log   : $backupLog (not yet created)" -ForegroundColor DarkGray
    }

    Write-Host "`nTip: To tail a log file in real time:" -ForegroundColor DarkGray
    Write-Host "  Get-Content '$LogDir\planning_stderr.log' -Wait -Tail 50" -ForegroundColor DarkGray
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

switch ($Action) {
    "install"   { Do-Install }
    "uninstall" { Do-Uninstall }
    "start"     { Do-Start }
    "stop"      { Do-Stop }
    "restart"   { Do-Restart }
    "status"    { Do-Status }
    "logs"      { Do-Logs }
}
