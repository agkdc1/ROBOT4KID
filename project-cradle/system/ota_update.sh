#!/bin/bash
# =============================================================================
# GCS OTA Update Script for Project Cradle
# =============================================================================
#
# Runs at boot via systemd service (cradle-ota.service).
# Checks a GCS bucket for a newer application bundle, downloads it if
# available, and restarts the cradle app service.
#
# Bucket layout:
#   gs://nl2bot-f7e604-cradle-ota/
#     latest.sha256          <- SHA-256 hash of the current release tarball
#     cradle-app.tar.gz      <- the release tarball
#
# Local layout:
#   /opt/cradle/app/         <- extracted application files
#   /opt/cradle/version.txt  <- SHA-256 of the currently installed release
#   /opt/cradle/backup/      <- previous version (one-deep rollback)
#   /var/log/cradle-ota.log  <- log output
#
# Requirements:
#   - gsutil (Google Cloud SDK) OR curl for public-read buckets
#   - systemd service "cradle-app" for the main application
#
# Install as a systemd service:
#   sudo cp cradle-ota.service /etc/systemd/system/
#   sudo systemctl enable cradle-ota
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

GCS_BUCKET="gs://nl2bot-f7e604-cradle-ota"
GCS_HTTP_BASE="https://storage.googleapis.com/nl2bot-f7e604-cradle-ota"

LOCAL_APP_DIR="/opt/cradle/app"
VERSION_FILE="/opt/cradle/version.txt"
BACKUP_DIR="/opt/cradle/backup"
DOWNLOAD_DIR="/tmp/cradle-ota"

APP_SERVICE="cradle-app"
LOG_FILE="/var/log/cradle-ota.log"

CONNECTIVITY_HOST="google.com"
CONNECTIVITY_TIMEOUT=5          # seconds
MAX_DOWNLOAD_RETRIES=3
DOWNLOAD_RETRY_DELAY=5          # seconds

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

log() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $*" | tee -a "$LOG_FILE"
}

log_error() { log "ERROR: $*"; }
log_ok()    { log "OK: $*"; }

# ---------------------------------------------------------------------------
# Ensure directories exist
# ---------------------------------------------------------------------------

mkdir -p "$LOCAL_APP_DIR" "$BACKUP_DIR" "$DOWNLOAD_DIR"
touch "$LOG_FILE"

# ---------------------------------------------------------------------------
# Step 1: Check for internet connectivity
# ---------------------------------------------------------------------------

log "--- OTA update check started ---"

if ! ping -c 1 -W "$CONNECTIVITY_TIMEOUT" "$CONNECTIVITY_HOST" >/dev/null 2>&1; then
    log "No internet connectivity. Skipping OTA check."
    exit 0
fi

log_ok "Internet connectivity confirmed."

# ---------------------------------------------------------------------------
# Step 2: Determine local version hash
# ---------------------------------------------------------------------------

LOCAL_HASH=""
if [[ -f "$VERSION_FILE" ]]; then
    LOCAL_HASH=$(cat "$VERSION_FILE" | tr -d '[:space:]')
    log "Local version hash: ${LOCAL_HASH:0:16}..."
else
    log "No local version file found. Will treat as first install."
fi

# ---------------------------------------------------------------------------
# Step 3: Fetch remote version hash
# ---------------------------------------------------------------------------

fetch_remote_hash() {
    # Prefer gsutil if available (works with private buckets too).
    if command -v gsutil >/dev/null 2>&1; then
        gsutil cat "${GCS_BUCKET}/latest.sha256" 2>/dev/null | tr -d '[:space:]'
    else
        curl -sf --max-time 10 "${GCS_HTTP_BASE}/latest.sha256" | tr -d '[:space:]'
    fi
}

REMOTE_HASH=$(fetch_remote_hash || true)

if [[ -z "$REMOTE_HASH" ]]; then
    log_error "Could not fetch remote version hash. Aborting."
    exit 1
fi

log "Remote version hash: ${REMOTE_HASH:0:16}..."

# ---------------------------------------------------------------------------
# Step 4: Compare hashes
# ---------------------------------------------------------------------------

if [[ "$LOCAL_HASH" == "$REMOTE_HASH" ]]; then
    log_ok "Already up to date. No update needed."
    exit 0
fi

log "New version detected. Starting download..."

# ---------------------------------------------------------------------------
# Step 5: Download the new release tarball
# ---------------------------------------------------------------------------

TARBALL="${DOWNLOAD_DIR}/cradle-app.tar.gz"

download_tarball() {
    if command -v gsutil >/dev/null 2>&1; then
        gsutil cp "${GCS_BUCKET}/cradle-app.tar.gz" "$TARBALL"
    else
        curl -sf --max-time 120 -o "$TARBALL" "${GCS_HTTP_BASE}/cradle-app.tar.gz"
    fi
}

downloaded=false
for attempt in $(seq 1 "$MAX_DOWNLOAD_RETRIES"); do
    log "Download attempt ${attempt}/${MAX_DOWNLOAD_RETRIES}..."
    if download_tarball; then
        downloaded=true
        break
    fi
    log_error "Download attempt $attempt failed."
    sleep "$DOWNLOAD_RETRY_DELAY"
done

if [[ "$downloaded" != "true" ]]; then
    log_error "All download attempts failed. Aborting."
    rm -f "$TARBALL"
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 6: Verify downloaded tarball
# ---------------------------------------------------------------------------

ACTUAL_HASH=$(sha256sum "$TARBALL" | awk '{print $1}')

if [[ "$ACTUAL_HASH" != "$REMOTE_HASH" ]]; then
    log_error "Hash mismatch! Expected ${REMOTE_HASH:0:16}... got ${ACTUAL_HASH:0:16}..."
    log_error "Download may be corrupted. Aborting."
    rm -f "$TARBALL"
    exit 1
fi

log_ok "Download verified (SHA-256 matches)."

# ---------------------------------------------------------------------------
# Step 7: Stop the app service
# ---------------------------------------------------------------------------

log "Stopping ${APP_SERVICE}..."
if systemctl is-active --quiet "$APP_SERVICE" 2>/dev/null; then
    sudo systemctl stop "$APP_SERVICE"
    log_ok "${APP_SERVICE} stopped."
else
    log "${APP_SERVICE} was not running."
fi

# ---------------------------------------------------------------------------
# Step 8: Backup current version
# ---------------------------------------------------------------------------

if [[ -d "$LOCAL_APP_DIR" ]] && [[ "$(ls -A "$LOCAL_APP_DIR" 2>/dev/null)" ]]; then
    log "Backing up current version to ${BACKUP_DIR}..."
    rm -rf "${BACKUP_DIR:?}/"*
    cp -a "$LOCAL_APP_DIR/." "$BACKUP_DIR/"
    if [[ -f "$VERSION_FILE" ]]; then
        cp "$VERSION_FILE" "${BACKUP_DIR}/version.txt"
    fi
    log_ok "Backup complete."
fi

# ---------------------------------------------------------------------------
# Step 9: Extract new version
# ---------------------------------------------------------------------------

log "Extracting new version to ${LOCAL_APP_DIR}..."
rm -rf "${LOCAL_APP_DIR:?}/"*
tar -xzf "$TARBALL" -C "$LOCAL_APP_DIR"

# Write the new version hash.
echo "$REMOTE_HASH" > "$VERSION_FILE"

log_ok "Extraction complete."

# ---------------------------------------------------------------------------
# Step 10: Restart the app service
# ---------------------------------------------------------------------------

log "Starting ${APP_SERVICE}..."
sudo systemctl start "$APP_SERVICE"

# Give it a few seconds, then verify.
sleep 3
if systemctl is-active --quiet "$APP_SERVICE" 2>/dev/null; then
    log_ok "Update successful! ${APP_SERVICE} is running."
else
    log_error "${APP_SERVICE} failed to start after update."

    # Attempt rollback.
    if [[ -d "$BACKUP_DIR" ]] && [[ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        log "Rolling back to previous version..."
        rm -rf "${LOCAL_APP_DIR:?}/"*
        cp -a "$BACKUP_DIR/." "$LOCAL_APP_DIR/"
        if [[ -f "${BACKUP_DIR}/version.txt" ]]; then
            cp "${BACKUP_DIR}/version.txt" "$VERSION_FILE"
        fi
        sudo systemctl start "$APP_SERVICE"
        if systemctl is-active --quiet "$APP_SERVICE" 2>/dev/null; then
            log_ok "Rollback successful. Running previous version."
        else
            log_error "Rollback also failed. Manual intervention required."
            exit 1
        fi
    else
        log_error "No backup available for rollback. Manual intervention required."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

rm -f "$TARBALL"
log "--- OTA update check finished ---"
