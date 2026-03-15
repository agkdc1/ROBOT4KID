#!/usr/bin/env bash
# ===========================================================================
# Setup Cloudflare Access applications and policies for NL2Bot
#
# Cloudflare Access sits in front of the tunnel endpoints and requires
# authentication before requests reach the origin servers.
#
# Prerequisites:
#   1. A Cloudflare API Token with these permissions:
#        - Account > Access: Apps and Policies > Edit
#        - Account > Access: Service Tokens > Edit
#        - Zone > DNS > Read  (for the domain)
#      Create at: https://dash.cloudflare.com/profile/api-tokens
#
#   2. Your Cloudflare Account ID (visible in the dashboard URL or
#      on the domain overview page, right sidebar).
#
# Usage:
#   export CF_API_TOKEN="your-cloudflare-api-token"
#   export CF_ACCOUNT_ID="your-cloudflare-account-id"
#   ./system/setup_cloudflare_access.sh [--allowed-emails email1,email2]
#
# Options:
#   --allowed-emails  Comma-separated list of emails to allow (or set CF_ALLOWED_EMAILS env var)
#   --dry-run         Print API calls without executing them
#   --store-secret    Store CF_ACCOUNT_ID in GCP Secret Manager
#   --delete          Remove the Access applications (cleanup)
#
# ===========================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ---- Defaults ----
# Domain is loaded from GCP Secret Manager (nl2bot-domains) or CF_DOMAIN env var.
# NEVER hardcode the real domain — it's stored in GCP SM for persistence.
DOMAIN="${CF_DOMAIN:-}"
if [[ -z "$DOMAIN" ]]; then
    # Try to fetch from GCP Secret Manager
    DOMAINS_JSON=$(gcloud secrets versions access latest --secret=nl2bot-domains --project="${GCP_PROJECT_ID:-nl2bot-f7e604}" 2>/dev/null || echo "")
    if [[ -n "$DOMAINS_JSON" ]]; then
        DOMAIN=$(echo "$DOMAINS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('domain',''))" 2>/dev/null || echo "")
    fi
    if [[ -z "$DOMAIN" ]]; then
        echo "ERROR: Set CF_DOMAIN env var or store domain in GCP SM (nl2bot-domains.domain)"
        exit 1
    fi
fi
PLAN_HOST="plan.${DOMAIN}"
SIM_HOST="sim.${DOMAIN}"
ALLOWED_EMAILS="${CF_ALLOWED_EMAILS:-}"
DRY_RUN=false
STORE_SECRET=false
DELETE_MODE=false
GCP_PROJECT="${GCP_PROJECT_ID:-nl2bot-f7e604}"

# ---- Parse args ----
while [[ $# -gt 0 ]]; do
    case "$1" in
        --allowed-emails) ALLOWED_EMAILS="$2"; shift 2 ;;
        --dry-run)        DRY_RUN=true; shift ;;
        --store-secret)   STORE_SECRET=true; shift ;;
        --delete)         DELETE_MODE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ---- Validate env vars ----
if [[ -z "${CF_API_TOKEN:-}" ]]; then
    echo "ERROR: CF_API_TOKEN is not set."
    echo ""
    echo "Create an API token at: https://dash.cloudflare.com/profile/api-tokens"
    echo "Required permissions:"
    echo "  - Account > Access: Apps and Policies > Edit"
    echo "  - Account > Access: Service Tokens > Edit"
    echo ""
    echo "Then: export CF_API_TOKEN='your-token-here'"
    exit 1
fi

if [[ -z "${CF_ACCOUNT_ID:-}" ]]; then
    echo "ERROR: CF_ACCOUNT_ID is not set."
    echo ""
    echo "Find your Account ID at:"
    echo "  https://dash.cloudflare.com  -> select domain -> right sidebar 'Account ID'"
    echo ""
    echo "Then: export CF_ACCOUNT_ID='your-account-id'"
    exit 1
fi

API_BASE="https://api.cloudflare.com/client/v4"
AUTH_HEADER="Authorization: Bearer ${CF_API_TOKEN}"
CONTENT_TYPE="Content-Type: application/json"

# ---- Helper functions ----

cf_api() {
    # Usage: cf_api METHOD ENDPOINT [DATA]
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    local url="${API_BASE}${endpoint}"

    if $DRY_RUN; then
        echo "[DRY RUN] ${method} ${url}"
        [[ -n "$data" ]] && echo "  Body: ${data}" | head -c 500
        echo ""
        return 0
    fi

    local args=(-s -X "$method" -H "$AUTH_HEADER" -H "$CONTENT_TYPE")
    [[ -n "$data" ]] && args+=(-d "$data")

    local response
    response=$(curl "${args[@]}" "$url")

    local success
    success=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null || echo "False")

    if [[ "$success" != "True" ]]; then
        echo "ERROR: API call failed: ${method} ${endpoint}"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
        return 1
    fi

    echo "$response"
}

get_existing_apps() {
    # List existing Access applications
    local response
    response=$(curl -s -X GET \
        -H "$AUTH_HEADER" \
        -H "$CONTENT_TYPE" \
        "${API_BASE}/accounts/${CF_ACCOUNT_ID}/access/apps")

    echo "$response"
}

find_app_by_domain() {
    # Find an Access app by its domain
    local domain="$1"
    local apps_json="$2"

    echo "$apps_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
apps = data.get('result', [])
for app in apps:
    if app.get('domain') == '${domain}':
        print(app['id'])
        sys.exit(0)
print('')
" 2>/dev/null
}

build_email_policy_include() {
    # Build the include rules for the policy from comma-separated emails
    local emails="$1"
    local rules="[]"

    rules=$(python3 -c "
import json
emails = '${emails}'.split(',')
rules = []
for email in emails:
    email = email.strip()
    if email:
        rules.append({'email': {'email': email}})
print(json.dumps(rules))
")
    echo "$rules"
}

create_access_app() {
    # Create an Access application for a subdomain
    local name="$1"
    local subdomain="$2"
    local session_duration="${3:-24h}"

    local app_data
    app_data=$(python3 -c "
import json
print(json.dumps({
    'name': '${name}',
    'domain': '${subdomain}',
    'type': 'self_hosted',
    'session_duration': '${session_duration}',
    'auto_redirect_to_identity': False,
    'app_launcher_visible': True,
    'allowed_idps': [],
    'enable_binding_cookie': False,
    'http_only_cookie_attribute': True,
    'same_site_cookie_attribute': 'lax',
    'logo_url': '',
    'skip_interstitial': True
}))
")

    echo "Creating Access application: ${name} (${subdomain})..."
    cf_api POST "/accounts/${CF_ACCOUNT_ID}/access/apps" "$app_data"
}

create_access_policy() {
    # Create an email-allow policy for an Access app
    local app_id="$1"
    local policy_name="$2"
    local include_rules="$3"

    local policy_data
    policy_data=$(python3 -c "
import json
include = json.loads('${include_rules}')
print(json.dumps({
    'name': '${policy_name}',
    'decision': 'allow',
    'include': include,
    'precedence': 1
}))
")

    echo "Creating Access policy: ${policy_name}..."
    cf_api POST "/accounts/${CF_ACCOUNT_ID}/access/apps/${app_id}/policies" "$policy_data"
}

delete_access_app() {
    local app_id="$1"
    local app_name="$2"

    echo "Deleting Access application: ${app_name} (${app_id})..."
    cf_api DELETE "/accounts/${CF_ACCOUNT_ID}/access/apps/${app_id}"
}

# ---- Main ----

echo "============================================="
echo "  NL2Bot Cloudflare Access Setup"
echo "============================================="
echo ""
echo "  Account ID:      ${CF_ACCOUNT_ID}"
echo "  Domain:          ${DOMAIN}"
echo "  Planning host:   ${PLAN_HOST}"
echo "  Simulation host: ${SIM_HOST}"
echo "  Allowed emails:  ${ALLOWED_EMAILS}"
echo "  Dry run:         ${DRY_RUN}"
echo ""

# Step 1: Verify API token is valid
echo "Step 1: Verifying API token..."
if ! $DRY_RUN; then
    verify_response=$(curl -s -X GET \
        -H "$AUTH_HEADER" \
        "${API_BASE}/user/tokens/verify")

    token_status=$(echo "$verify_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('result', {}).get('status', 'unknown'))
" 2>/dev/null || echo "error")

    if [[ "$token_status" != "active" ]]; then
        echo "ERROR: API token verification failed (status: ${token_status})"
        echo "$verify_response" | python3 -m json.tool 2>/dev/null || echo "$verify_response"
        exit 1
    fi
    echo "  Token verified: active"
else
    echo "  [DRY RUN] Skipping token verification"
fi

# Step 2: Check existing Access applications
echo ""
echo "Step 2: Checking existing Access applications..."
if ! $DRY_RUN; then
    existing_apps=$(get_existing_apps)
    plan_app_id=$(find_app_by_domain "$PLAN_HOST" "$existing_apps")
    sim_app_id=$(find_app_by_domain "$SIM_HOST" "$existing_apps")

    if [[ -n "$plan_app_id" ]]; then
        echo "  Found existing app for ${PLAN_HOST}: ${plan_app_id}"
    else
        echo "  No existing app for ${PLAN_HOST}"
    fi

    if [[ -n "$sim_app_id" ]]; then
        echo "  Found existing app for ${SIM_HOST}: ${sim_app_id}"
    else
        echo "  No existing app for ${SIM_HOST}"
    fi
else
    plan_app_id=""
    sim_app_id=""
    echo "  [DRY RUN] Skipping existing app check"
fi

# Delete mode
if $DELETE_MODE; then
    echo ""
    echo "Step 3: Deleting Access applications..."
    if [[ -n "$plan_app_id" ]]; then
        delete_access_app "$plan_app_id" "NL2Bot Planning"
    else
        echo "  No planning app to delete"
    fi
    if [[ -n "$sim_app_id" ]]; then
        delete_access_app "$sim_app_id" "NL2Bot Simulation"
    else
        echo "  No simulation app to delete"
    fi
    echo ""
    echo "Done. Access applications removed."
    exit 0
fi

# Step 3: Build email policy rules
echo ""
echo "Step 3: Building access policy..."
include_rules=$(build_email_policy_include "$ALLOWED_EMAILS")
echo "  Include rules: ${include_rules}"

# Step 4: Create Access applications
echo ""
echo "Step 4: Creating Access applications..."

# Planning server
if [[ -z "$plan_app_id" ]]; then
    plan_response=$(create_access_app "NL2Bot Planning" "$PLAN_HOST" "24h")
    if ! $DRY_RUN; then
        plan_app_id=$(echo "$plan_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('result', {}).get('id', ''))
" 2>/dev/null)
        echo "  Created planning app: ${plan_app_id}"
    fi
else
    echo "  Planning app already exists: ${plan_app_id} (skipping)"
fi

# Simulation server
if [[ -z "$sim_app_id" ]]; then
    sim_response=$(create_access_app "NL2Bot Simulation" "$SIM_HOST" "24h")
    if ! $DRY_RUN; then
        sim_app_id=$(echo "$sim_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('result', {}).get('id', ''))
" 2>/dev/null)
        echo "  Created simulation app: ${sim_app_id}"
    fi
else
    echo "  Simulation app already exists: ${sim_app_id} (skipping)"
fi

# Step 5: Create Access policies (email-based allow)
echo ""
echo "Step 5: Creating Access policies..."

if [[ -n "$plan_app_id" ]] && ! $DRY_RUN; then
    create_access_policy "$plan_app_id" "Allow NL2Bot Users" "$include_rules"
    echo "  Created policy for planning app"
fi

if [[ -n "$sim_app_id" ]] && ! $DRY_RUN; then
    create_access_policy "$sim_app_id" "Allow NL2Bot Users" "$include_rules"
    echo "  Created policy for simulation app"
fi

if $DRY_RUN; then
    echo "  [DRY RUN] Would create email-allow policies for both apps"
fi

# Step 6: Optionally store CF_ACCOUNT_ID in GCP Secret Manager
if $STORE_SECRET; then
    echo ""
    echo "Step 6: Storing CF_ACCOUNT_ID in GCP Secret Manager..."

    # Check if secret exists
    if gcloud secrets describe cf-account-id --project="${GCP_PROJECT}" >/dev/null 2>&1; then
        echo "  Secret 'cf-account-id' already exists, adding new version..."
        echo -n "${CF_ACCOUNT_ID}" | gcloud secrets versions add cf-account-id \
            --data-file=- --project="${GCP_PROJECT}"
    else
        echo "  Creating secret 'cf-account-id'..."
        gcloud secrets create cf-account-id \
            --replication-policy=automatic \
            --project="${GCP_PROJECT}"
        echo -n "${CF_ACCOUNT_ID}" | gcloud secrets versions add cf-account-id \
            --data-file=- --project="${GCP_PROJECT}"
    fi
    echo "  Stored CF_ACCOUNT_ID in GCP Secret Manager"
fi

# Step 7: Summary
echo ""
echo "============================================="
echo "  Setup Complete"
echo "============================================="
echo ""
echo "  Planning:   https://${PLAN_HOST} (Access-protected)"
echo "  Simulation: https://${SIM_HOST} (Access-protected)"
echo ""
echo "  Users must authenticate via email OTP before"
echo "  reaching the origin servers."
echo ""
echo "  Manage Access apps at:"
echo "    https://one.dash.cloudflare.com/${CF_ACCOUNT_ID}/access/apps"
echo ""
echo "  To add GitHub/Google IdP:"
echo "    https://one.dash.cloudflare.com/${CF_ACCOUNT_ID}/access/identity-providers"
echo ""
if ! $DRY_RUN; then
    echo "  App IDs:"
    echo "    Planning:   ${plan_app_id}"
    echo "    Simulation: ${sim_app_id}"
    echo ""
fi
echo "  Next steps:"
echo "    1. Test: visit https://${PLAN_HOST} — you should see the Access login page"
echo "    2. (Optional) Add identity providers (GitHub, Google) in the dashboard"
echo "    3. (Optional) Add more allowed emails: --allowed-emails email1,email2"
echo ""
