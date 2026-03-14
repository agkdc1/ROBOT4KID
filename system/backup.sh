#!/usr/bin/env bash
# NL2Bot Backup Script — uploads project data to GCS
# Usage: ./system/backup.sh [tag]
# Example: ./system/backup.sh v1.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Config
GCP_PROJECT="${GCP_PROJECT_ID:-nl2bot-f7e604}"
BUCKET="gs://${GCP_PROJECT}-backup"
TAG="${1:-$(date +%Y%m%d-%H%M%S)}"
BACKUP_DIR="/tmp/nl2bot-backup-${TAG}"

echo "=== NL2Bot Backup (tag: ${TAG}) ==="

# Create temp backup directory
mkdir -p "${BACKUP_DIR}"

# 1. Database
if [ -f "${PROJECT_ROOT}/planning_server/data/db.sqlite3" ]; then
    cp "${PROJECT_ROOT}/planning_server/data/db.sqlite3" "${BACKUP_DIR}/db.sqlite3"
    echo "[+] Database copied"
fi

# 2. Project data (generated SCAD, specs, feedback)
if [ -d "${PROJECT_ROOT}/planning_server/data/projects" ]; then
    cp -r "${PROJECT_ROOT}/planning_server/data/projects" "${BACKUP_DIR}/projects"
    echo "[+] Project data copied"
fi

# 3. Simulation jobs
if [ -d "${PROJECT_ROOT}/simulation_server/jobs" ]; then
    cp -r "${PROJECT_ROOT}/simulation_server/jobs" "${BACKUP_DIR}/jobs"
    echo "[+] Simulation jobs copied"
fi

# 4. Environment config (without secrets — secrets are in Secret Manager)
if [ -f "${PROJECT_ROOT}/.env" ]; then
    grep -v '_KEY\|_SECRET\|PASSWORD' "${PROJECT_ROOT}/.env" > "${BACKUP_DIR}/env.nonsecret" || true
    echo "[+] Non-secret env config copied"
fi

# 5. Terraform state
if [ -f "${PROJECT_ROOT}/infra/terraform/terraform.tfstate" ]; then
    cp "${PROJECT_ROOT}/infra/terraform/terraform.tfstate" "${BACKUP_DIR}/terraform.tfstate"
    echo "[+] Terraform state copied"
fi

# Create archive
ARCHIVE="/tmp/nl2bot-backup-${TAG}.tar.gz"
tar -czf "${ARCHIVE}" -C /tmp "nl2bot-backup-${TAG}"
echo "[+] Archive created: ${ARCHIVE}"

# Upload to GCS
gsutil cp "${ARCHIVE}" "${BUCKET}/backups/nl2bot-backup-${TAG}.tar.gz"
echo "[+] Uploaded to ${BUCKET}/backups/nl2bot-backup-${TAG}.tar.gz"

# Cleanup
rm -rf "${BACKUP_DIR}" "${ARCHIVE}"
echo "=== Backup complete ==="
