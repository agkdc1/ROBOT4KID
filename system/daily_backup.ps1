<#
.SYNOPSIS
    NL2Bot Daily Backup — uploads project data to GCS.
    Runs as a Windows Scheduled Task (daily at 03:00).
.USAGE
    .\system\daily_backup.ps1                 # Run backup now
    .\system\daily_backup.ps1 -Register       # Register scheduled task
    .\system\daily_backup.ps1 -Unregister     # Remove scheduled task
    .\system\daily_backup.ps1 -Status         # Check task status
    .\system\daily_backup.ps1 -Tag v1.0       # Run with custom tag
#>

param(
    [switch]$Register,
    [switch]$Unregister,
    [switch]$Status,
    [string]$Tag = "",
    [string]$Time = "03:00"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Users\ahnch\Documents\ROBOT4KID"
$LogDir      = "$ProjectRoot\logs"
$TaskName    = "NL2Bot-DailyBackup"
$GcpProject  = "nl2bot-f7e604"
$Bucket      = "gs://${GcpProject}-backup"

# ---------------------------------------------------------------------------
# Scheduled Task Management
# ---------------------------------------------------------------------------

if ($Register) {
    # Create logs directory
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) {
        $scriptPath = "$ProjectRoot\system\daily_backup.ps1"
    }

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
        -WorkingDirectory $ProjectRoot

    $trigger = New-ScheduledTaskTrigger -Daily -At $Time

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
        -RestartCount 2 `
        -RestartInterval (New-TimeSpan -Minutes 10)

    # Remove existing task if present
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Removed existing task." -ForegroundColor Yellow
    }

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Description "NL2Bot daily backup to GCS (runs at $Time)" `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -RunLevel Highest `
        -User $env:USERNAME | Out-Null

    Write-Host "Scheduled task '$TaskName' registered." -ForegroundColor Green
    Write-Host "  Schedule : Daily at $Time"
    Write-Host "  Script   : $scriptPath"
    Write-Host "  Log      : $LogDir\backup.log"
    Write-Host ""
    Write-Host "To run immediately: schtasks /Run /TN `"$TaskName`"" -ForegroundColor DarkGray
    exit 0
}

if ($Unregister) {
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Scheduled task '$TaskName' removed." -ForegroundColor Green
    } else {
        Write-Host "Task '$TaskName' is not registered." -ForegroundColor Yellow
    }
    exit 0
}

if ($Status) {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        $info = Get-ScheduledTaskInfo -TaskName $TaskName
        Write-Host ""
        Write-Host "NL2Bot Daily Backup Task" -ForegroundColor Cyan
        Write-Host ("-" * 40)
        Write-Host ("  State         : {0}" -f $task.State)
        Write-Host ("  Last Run      : {0}" -f $info.LastRunTime)
        Write-Host ("  Last Result   : {0}" -f $info.LastTaskResult)
        Write-Host ("  Next Run      : {0}" -f $info.NextRunTime)
        Write-Host ""

        # Show last few lines of backup log
        $logFile = "$LogDir\backup.log"
        if (Test-Path $logFile) {
            Write-Host "Recent log:" -ForegroundColor DarkGray
            Get-Content $logFile -Tail 10 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "Task '$TaskName' is not registered." -ForegroundColor Yellow
        Write-Host "Register with: .\system\daily_backup.ps1 -Register" -ForegroundColor DarkGray
    }
    exit 0
}

# ---------------------------------------------------------------------------
# Backup Execution
# ---------------------------------------------------------------------------

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$logFile  = "$LogDir\backup.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if ($Tag -eq "") {
    $Tag = Get-Date -Format "yyyyMMdd-HHmmss"
}

$backupDir = "$env:TEMP\nl2bot-backup-$Tag"

function Log($msg) {
    $line = "[$timestamp] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Log "=== NL2Bot Backup (tag: $Tag) ==="

try {
    # Create temp backup directory
    if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force }
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    # 1. Database
    $dbPath = "$ProjectRoot\planning_server\data\db.sqlite3"
    if (Test-Path $dbPath) {
        Copy-Item $dbPath "$backupDir\db.sqlite3"
        Log "[+] Database copied"
    }

    # 2. Project data
    $projectsDir = "$ProjectRoot\planning_server\data\projects"
    if (Test-Path $projectsDir) {
        Copy-Item $projectsDir "$backupDir\projects" -Recurse
        Log "[+] Project data copied"
    }

    # 3. Simulation jobs
    $jobsDir = "$ProjectRoot\simulation_server\jobs"
    if (Test-Path $jobsDir) {
        Copy-Item $jobsDir "$backupDir\jobs" -Recurse
        Log "[+] Simulation jobs copied"
    }

    # 4. Non-secret env config
    $envPath = "$ProjectRoot\.env"
    if (Test-Path $envPath) {
        Get-Content $envPath | Where-Object {
            $_ -notmatch '_KEY|_SECRET|PASSWORD'
        } | Set-Content "$backupDir\env.nonsecret"
        Log "[+] Non-secret env config copied"
    }

    # 5. Terraform state
    $tfState = "$ProjectRoot\infra\terraform\terraform.tfstate"
    if (Test-Path $tfState) {
        Copy-Item $tfState "$backupDir\terraform.tfstate"
        Log "[+] Terraform state copied"
    }

    # 6. Hardware config
    $hwConfig = "$ProjectRoot\config\hardware_specs.yaml"
    if (Test-Path $hwConfig) {
        Copy-Item $hwConfig "$backupDir\hardware_specs.yaml"
        Log "[+] Hardware config copied"
    }

    # Create archive
    $archive = "$env:TEMP\nl2bot-backup-$Tag.tar.gz"
    if (Test-Path $archive) { Remove-Item $archive -Force }

    # Use tar (available on Windows 10+)
    tar -czf $archive -C $env:TEMP "nl2bot-backup-$Tag"
    if ($LASTEXITCODE -ne 0) { throw "tar failed with exit code $LASTEXITCODE" }
    $sizeMB = [math]::Round((Get-Item $archive).Length / 1MB, 2)
    Log "[+] Archive created: $archive ($sizeMB MB)"

    # Upload to GCS
    $gcloud = "gcloud.cmd"
    & $gcloud storage cp $archive "$Bucket/backups/nl2bot-backup-$Tag.tar.gz" --quiet
    if ($LASTEXITCODE -ne 0) { throw "GCS upload failed with exit code $LASTEXITCODE" }
    Log "[+] Uploaded to $Bucket/backups/nl2bot-backup-$Tag.tar.gz"

    # Move backups older than 30 days to Archive storage class (cheapest)
    $cutoffDate = (Get-Date).AddDays(-30).ToString("yyyyMMdd")
    $listing = & $gcloud storage ls "$Bucket/backups/" --quiet 2>&1
    if ($LASTEXITCODE -eq 0) {
        $oldBackups = $listing | Where-Object {
            $_ -match "nl2bot-backup-(\d{8})-" -and $Matches[1] -lt $cutoffDate
        }
        foreach ($old in $oldBackups) {
            & $gcloud storage objects update $old --storage-class=ARCHIVE --quiet 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Log "[~] Moved to ARCHIVE: $old"
            }
        }
    }

    # Cleanup local temp
    Remove-Item $backupDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $archive -Force -ErrorAction SilentlyContinue

    Log "=== Backup complete ==="

} catch {
    Log "[ERROR] Backup failed: $_"
    # Cleanup on failure
    Remove-Item $backupDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\nl2bot-backup-$Tag.tar.gz" -Force -ErrorAction SilentlyContinue
    exit 1
}
