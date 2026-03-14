#!/usr/bin/env bash
# NL2Bot Flutter App Deployment Script (bash wrapper)
# Usage: ./system/deploy_app.sh [--release] [--device SERIAL] [--clean]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"

RELEASE=""
DEVICE=""
CLEAN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --release) RELEASE="--release" ;;
        --device) DEVICE="$2"; shift ;;
        --clean) CLEAN="1" ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

echo "=== NL2Bot App Deployment ==="

# Check prerequisites
command -v flutter >/dev/null || { echo "ERROR: flutter not found"; exit 1; }
command -v adb >/dev/null || { echo "ERROR: adb not found"; exit 1; }

# Check device
DEVICES=$(adb devices | grep -c "device$" || true)
if [ "$DEVICES" -eq 0 ]; then
    echo "ERROR: No Android device connected"
    exit 1
fi
echo "[+] Device(s) found"

cd "$FRONTEND_DIR"

[ -n "$CLEAN" ] && flutter clean
flutter pub get

BUILD_MODE=${RELEASE:-"--debug"}
echo "[+] Building ($BUILD_MODE)..."
flutter build apk $BUILD_MODE

APK_DIR="build/app/outputs/flutter-apk"
APK_FILE=$([ -n "$RELEASE" ] && echo "app-release.apk" || echo "app-debug.apk")
APK_PATH="${APK_DIR}/${APK_FILE}"

[ ! -f "$APK_PATH" ] && { echo "ERROR: APK not found"; exit 1; }

echo "[+] Installing..."
DEVICE_ARG=""
[ -n "$DEVICE" ] && DEVICE_ARG="-s $DEVICE"
adb $DEVICE_ARG install -r "$APK_PATH"

echo "[+] Launching..."
adb $DEVICE_ARG shell am start -n com.nl2bot.controller/.MainActivity

echo "=== Deployment complete ==="
