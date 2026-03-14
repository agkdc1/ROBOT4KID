#!/usr/bin/env bash
# Fetch secrets from GCP Secret Manager and write .env
# Usage: ./system/fetch_secrets.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

GCP_PROJECT="${GCP_PROJECT_ID:-nl2bot-f7e604}"

echo "Fetching secrets from project: ${GCP_PROJECT}"

ANTHROPIC_KEY=$(gcloud secrets versions access latest --secret=anthropic-api-key --project="${GCP_PROJECT}" 2>/dev/null)
GEMINI_KEY=$(gcloud secrets versions access latest --secret=gemini-api-key --project="${GCP_PROJECT}" 2>/dev/null)
JWT_KEY=$(gcloud secrets versions access latest --secret=jwt-secret-key --project="${GCP_PROJECT}" 2>/dev/null)
SIM_KEY=$(gcloud secrets versions access latest --secret=sim-api-key --project="${GCP_PROJECT}" 2>/dev/null)
ADMIN_PW=$(gcloud secrets versions access latest --secret=nl2bot-admin-password --project="${GCP_PROJECT}" 2>/dev/null)

cat > "${PROJECT_ROOT}/.env" << EOF
# NL2Bot Environment (fetched from GCP Secret Manager)
ANTHROPIC_API_KEY=${ANTHROPIC_KEY}
GEMINI_API_KEY=${GEMINI_KEY}
GCP_PROJECT_ID=${GCP_PROJECT}
JWT_SECRET_KEY=${JWT_KEY}
ADMIN_USERNAME=admin
ADMIN_PASSWORD=${ADMIN_PW}
SIMULATION_SERVER_URL=http://localhost:8100
PLAN_PORT=8000
SIM_PORT=8100

# Simulation server API key (service-to-service auth)
SIM_API_KEY=${SIM_KEY}

# Pipeline settings
MAX_REFINEMENT_ITERATIONS=2
EOF

echo ".env written with secrets from GCP Secret Manager"
