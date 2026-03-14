# NL2Bot Flutter App Deployment Script (Windows + ADB)
# Usage: .\system\deploy_app.ps1 [-Release] [-Device <serial>]
#
# Prerequisites:
#   - Flutter SDK in PATH
#   - ADB in PATH (from Android SDK platform-tools)
#   - USB debugging enabled on tablet
#   - Tablet connected via USB

param(
    [switch]$Release,
    [string]$Device = "",
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$FrontendDir = Join-Path $ProjectRoot "frontend"

Write-Host "=== NL2Bot App Deployment ===" -ForegroundColor Cyan

# Check prerequisites
Write-Host "[1/5] Checking prerequisites..." -ForegroundColor Yellow

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Host "ERROR: Flutter not found in PATH" -ForegroundColor Red
    exit 1
}

$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) {
    Write-Host "ERROR: ADB not found in PATH" -ForegroundColor Red
    exit 1
}

# Check connected devices
Write-Host "[2/5] Checking connected devices..." -ForegroundColor Yellow
$devices = adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "device$" }
if (-not $devices) {
    Write-Host "ERROR: No Android device connected. Enable USB debugging and connect tablet." -ForegroundColor Red
    exit 1
}

Write-Host "  Found device(s):" -ForegroundColor Green
$devices | ForEach-Object { Write-Host "    $_" }

# Build
Write-Host "[3/5] Building Flutter app..." -ForegroundColor Yellow
Push-Location $FrontendDir

if ($Clean) {
    Write-Host "  Cleaning..." -ForegroundColor Gray
    flutter clean
}

flutter pub get

$buildMode = if ($Release) { "--release" } else { "--debug" }
$deviceArg = if ($Device) { "-d $Device" } else { "" }

Write-Host "  Building ($($Release ? 'release' : 'debug'))..." -ForegroundColor Gray
flutter build apk $buildMode

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Find APK
$apkPath = if ($Release) {
    Join-Path $FrontendDir "build\app\outputs\flutter-apk\app-release.apk"
} else {
    Join-Path $FrontendDir "build\app\outputs\flutter-apk\app-debug.apk"
}

if (-not (Test-Path $apkPath)) {
    Write-Host "ERROR: APK not found at $apkPath" -ForegroundColor Red
    Pop-Location
    exit 1
}

$apkSize = (Get-Item $apkPath).Length / 1MB
Write-Host "  APK built: $([math]::Round($apkSize, 1)) MB" -ForegroundColor Green

# Install
Write-Host "[4/5] Installing on device..." -ForegroundColor Yellow
$installArgs = @("-r", $apkPath)
if ($Device) { $installArgs = @("-s", $Device) + $installArgs }

adb install @installArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Installation failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Launch
Write-Host "[5/5] Launching app..." -ForegroundColor Yellow
$launchArgs = @("shell", "am", "start", "-n", "com.nl2bot.controller/.MainActivity")
if ($Device) { $launchArgs = @("-s", $Device) + $launchArgs }

adb @launchArgs

Pop-Location

Write-Host ""
Write-Host "=== Deployment complete ===" -ForegroundColor Green
Write-Host "  App installed and launched on device." -ForegroundColor Green
