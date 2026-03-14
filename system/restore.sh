#!/usr/bin/env bash
# NL2Bot Restore Script — downloads backup from GCS and restores
# Usage: ./system/restore.sh <tag>
# Example: ./system/restore.sh 20260314-120000
# List available: ./system/restore.sh --list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Config
GCP_PROJECT="${GCP_PROJECT_ID:-nl2bot-f7e604}"
BUCKET="gs://${GCP_PROJECT}-backup"

if [ "${1:-}" = "--list" ]; then
    echo "=== Available backups ==="
    gsutil ls "${BUCKET}/backups/" 2>/dev/null || echo "No backups found"
    exit 0
fi

TAG="${1:?Usage: restore.sh <tag> or restore.sh --list}"
ARCHIVE="/tmp/nl2bot-backup-${TAG}.tar.gz"
RESTORE_DIR="/tmp/nl2bot-backup-${TAG}"

echo "=== NL2Bot Restore (tag: ${TAG}) ==="

# Download from GCS
gsutil cp "${BUCKET}/backups/nl2bot-backup-${TAG}.tar.gz" "${ARCHIVE}"
echo "[+] Downloaded backup"

# Extract
tar -xzf "${ARCHIVE}" -C /tmp
echo "[+] Extracted archive"

# 1. Database
if [ -f "${RESTORE_DIR}/db.sqlite3" ]; then
    mkdir -p "${PROJECT_ROOT}/planning_server/data"
    cp "${RESTORE_DIR}/db.sqlite3" "${PROJECT_ROOT}/planning_server/data/db.sqlite3"
    echo "[+] Database restored"
fi

# 2. Project data
if [ -d "${RESTORE_DIR}/projects" ]; then
    mkdir -p "${PROJECT_ROOT}/planning_server/data"
    cp -r "${RESTORE_DIR}/projects" "${PROJECT_ROOT}/planning_server/data/projects"
    echo "[+] Project data restored"
fi

# 3. Simulation jobs
if [ -d "${RESTORE_DIR}/jobs" ]; then
    cp -r "${RESTORE_DIR}/jobs" "${PROJECT_ROOT}/simulation_server/jobs"
    echo "[+] Simulation jobs restored"
fi

# 4. Terraform state
if [ -f "${RESTORE_DIR}/terraform.tfstate" ]; then
    mkdir -p "${PROJECT_ROOT}/infra/terraform"
    cp "${RESTORE_DIR}/terraform.tfstate" "${PROJECT_ROOT}/infra/terraform/terraform.tfstate"
    echo "[+] Terraform state restored"
fi

# Cleanup
rm -rf "${RESTORE_DIR}" "${ARCHIVE}"

echo "=== Restore complete ==="
echo "To restore secrets, run:"
echo "  gcloud secrets versions access latest --secret=anthropic-api-key --project=${GCP_PROJECT}"
echo "  gcloud secrets versions access latest --secret=gemini-api-key --project=${GCP_PROJECT}"
echo "  gcloud secrets versions access latest --secret=jwt-secret-key --project=${GCP_PROJECT}"
