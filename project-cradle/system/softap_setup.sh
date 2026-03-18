#!/bin/bash
# =============================================================================
# SoftAP Setup for Project Cradle
# =============================================================================
#
# Each cradle gets a unique Wi-Fi access point so the ESP32 robot can
# connect without any pre-existing network infrastructure.
#
# What this script does:
#   1. Generate a unique SSID:  CRADLE_<random 6 alphanumeric chars>
#   2. Generate a random 12-character WPA2 password
#   3. Configure hostapd + dnsmasq for a SoftAP on wlan0
#   4. Push the SSID and password to GCP Secret Manager so that the
#      ESP32 firmware build can retrieve them at flash time
#   5. Enable and start the services
#
# Requirements:
#   - Raspberry Pi OS (Bookworm or later)
#   - hostapd, dnsmasq packages
#   - gcloud CLI authenticated (for Secret Manager push)
#
# Usage:
#   sudo ./softap_setup.sh                     # full setup
#   sudo ./softap_setup.sh --dry-run           # preview only
#   sudo ./softap_setup.sh --profile tank-01   # named profile
#   sudo ./softap_setup.sh --skip-gcp          # no Secret Manager push
#   sudo ./softap_setup.sh --delete            # tear down SoftAP config
#
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

WLAN_IFACE="wlan0"
AP_IP="192.168.4.1"
AP_NETMASK="255.255.255.0"
DHCP_RANGE_START="192.168.4.10"
DHCP_RANGE_END="192.168.4.50"
DHCP_LEASE="12h"
AP_CHANNEL=6
AP_COUNTRY="US"

GCP_PROJECT="nl2bot-f7e604"
GCP_SECRET_PREFIX="cradle-wifi"

HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
DNSMASQ_CONF="/etc/dnsmasq.d/cradle-ap.conf"
CREDENTIALS_FILE="/opt/cradle/wifi_credentials.json"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

DRY_RUN=false
SKIP_GCP=false
DELETE_MODE=false
PROFILE_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)    DRY_RUN=true;   shift ;;
        --skip-gcp)   SKIP_GCP=true;  shift ;;
        --delete)     DELETE_MODE=true; shift ;;
        --profile)    PROFILE_NAME="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: sudo $0 [--dry-run] [--skip-gcp] [--delete] [--profile NAME]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log()       { echo "[$(date '+%H:%M:%S')] $*"; }
log_ok()    { log "OK: $*"; }
log_error() { log "ERROR: $*" >&2; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)."
        exit 1
    fi
}

generate_random_alphanum() {
    local length=$1
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

generate_ssid() {
    local suffix
    suffix=$(generate_random_alphanum 6 | tr '[:lower:]' '[:upper:]')
    echo "CRADLE_${suffix}"
}

generate_password() {
    # 12-char password: mix of upper, lower, digits.  Avoid ambiguous chars.
    generate_random_alphanum 12
}

# ---------------------------------------------------------------------------
# Delete mode
# ---------------------------------------------------------------------------

do_delete() {
    require_root
    log "Tearing down SoftAP configuration..."

    systemctl stop hostapd 2>/dev/null || true
    systemctl stop dnsmasq 2>/dev/null || true
    systemctl disable hostapd 2>/dev/null || true

    rm -f "$HOSTAPD_CONF" "$DNSMASQ_CONF" "$CREDENTIALS_FILE"

    # Restore NetworkManager control of the interface.
    if [[ -f "/etc/NetworkManager/conf.d/cradle-unmanaged.conf" ]]; then
        rm -f "/etc/NetworkManager/conf.d/cradle-unmanaged.conf"
        systemctl restart NetworkManager 2>/dev/null || true
    fi

    log_ok "SoftAP configuration removed."
    exit 0
}

[[ "$DELETE_MODE" == "true" ]] && do_delete

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

require_root

for pkg in hostapd dnsmasq; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        log "Installing $pkg..."
        if [[ "$DRY_RUN" == "true" ]]; then
            log "(dry-run) apt-get install -y $pkg"
        else
            apt-get install -y "$pkg"
        fi
    fi
done

# ---------------------------------------------------------------------------
# Step 1 & 2: Generate SSID and password
# ---------------------------------------------------------------------------

SSID=$(generate_ssid)
PASSWORD=$(generate_password)

if [[ -n "$PROFILE_NAME" ]]; then
    log "Profile: $PROFILE_NAME"
fi
log "Generated SSID:     $SSID"
log "Generated Password: $PASSWORD"

if [[ "$DRY_RUN" == "true" ]]; then
    log "(dry-run) Would configure hostapd, dnsmasq, and push to GCP."
    log "(dry-run) No changes made."
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 3a: Configure hostapd
# ---------------------------------------------------------------------------

log "Writing hostapd configuration..."

cat > "$HOSTAPD_CONF" <<HOSTAPD_EOF
# Project Cradle SoftAP — auto-generated, do not edit manually
interface=${WLAN_IFACE}
driver=nl80211
ssid=${SSID}
hw_mode=g
channel=${AP_CHANNEL}
country_code=${AP_COUNTRY}

# WPA2-PSK
wpa=2
wpa_passphrase=${PASSWORD}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP

# Performance
wmm_enabled=1
ieee80211n=1

# Limit to 4 clients (one robot + margin)
max_num_sta=4
HOSTAPD_EOF

chmod 600 "$HOSTAPD_CONF"

# Point hostapd daemon config to our file.
if [[ -f /etc/default/hostapd ]]; then
    sed -i 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
fi

log_ok "hostapd configured."

# ---------------------------------------------------------------------------
# Step 3b: Configure dnsmasq
# ---------------------------------------------------------------------------

log "Writing dnsmasq configuration..."

cat > "$DNSMASQ_CONF" <<DNSMASQ_EOF
# Project Cradle DHCP — auto-generated, do not edit manually
interface=${WLAN_IFACE}
bind-interfaces
dhcp-range=${DHCP_RANGE_START},${DHCP_RANGE_END},${AP_NETMASK},${DHCP_LEASE}

# Disable DNS forwarding (robot doesn't need internet via this AP)
port=0
DNSMASQ_EOF

log_ok "dnsmasq configured."

# ---------------------------------------------------------------------------
# Step 3c: Set static IP on the wireless interface
# ---------------------------------------------------------------------------

log "Configuring static IP ${AP_IP} on ${WLAN_IFACE}..."

# Prevent NetworkManager from managing this interface.
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/cradle-unmanaged.conf <<NM_EOF
[keyfile]
unmanaged-devices=interface-name:${WLAN_IFACE}
NM_EOF

# Configure via dhcpcd (standard on RPi OS).
if [[ -f /etc/dhcpcd.conf ]]; then
    # Remove any previous cradle block.
    sed -i '/# CRADLE-AP-BEGIN/,/# CRADLE-AP-END/d' /etc/dhcpcd.conf

    cat >> /etc/dhcpcd.conf <<DHCPCD_EOF

# CRADLE-AP-BEGIN
interface ${WLAN_IFACE}
    static ip_address=${AP_IP}/24
    nohook wpa_supplicant
# CRADLE-AP-END
DHCPCD_EOF
fi

log_ok "Static IP configured."

# ---------------------------------------------------------------------------
# Step 3d: Enable and start services
# ---------------------------------------------------------------------------

log "Enabling services..."

systemctl unmask hostapd 2>/dev/null || true
systemctl enable hostapd
systemctl enable dnsmasq

# Restart networking stack.
systemctl restart dhcpcd 2>/dev/null || true
sleep 2
systemctl restart dnsmasq
systemctl restart hostapd

# Verify.
if systemctl is-active --quiet hostapd; then
    log_ok "hostapd is running."
else
    log_error "hostapd failed to start. Check: journalctl -u hostapd"
fi

if systemctl is-active --quiet dnsmasq; then
    log_ok "dnsmasq is running."
else
    log_error "dnsmasq failed to start. Check: journalctl -u dnsmasq"
fi

# ---------------------------------------------------------------------------
# Step 4: Save credentials locally
# ---------------------------------------------------------------------------

log "Saving credentials to ${CREDENTIALS_FILE}..."

mkdir -p "$(dirname "$CREDENTIALS_FILE")"
cat > "$CREDENTIALS_FILE" <<CRED_EOF
{
  "ssid": "${SSID}",
  "password": "${PASSWORD}",
  "ip": "${AP_IP}",
  "profile": "${PROFILE_NAME:-default}",
  "created": "$(date -Iseconds)"
}
CRED_EOF

chmod 600 "$CREDENTIALS_FILE"
log_ok "Credentials saved."

# ---------------------------------------------------------------------------
# Step 5: Push to GCP Secret Manager
# ---------------------------------------------------------------------------

if [[ "$SKIP_GCP" == "true" ]]; then
    log "Skipping GCP Secret Manager push (--skip-gcp)."
else
    SECRET_NAME="${GCP_SECRET_PREFIX}"
    if [[ -n "$PROFILE_NAME" ]]; then
        SECRET_NAME="${GCP_SECRET_PREFIX}-${PROFILE_NAME}"
    fi

    log "Pushing credentials to GCP Secret Manager: ${SECRET_NAME}..."

    # Use gcloud.cmd on Windows, gcloud on Linux.
    GCLOUD="gcloud"
    if command -v gcloud.cmd >/dev/null 2>&1; then
        GCLOUD="gcloud.cmd"
    fi

    # Create the secret if it doesn't exist.
    if ! $GCLOUD secrets describe "$SECRET_NAME" --project="$GCP_PROJECT" >/dev/null 2>&1; then
        $GCLOUD secrets create "$SECRET_NAME" \
            --project="$GCP_PROJECT" \
            --replication-policy="automatic" \
            --labels="component=cradle,type=wifi"
        log "Created new secret: ${SECRET_NAME}"
    fi

    # Add a new version with the credentials JSON.
    $GCLOUD secrets versions add "$SECRET_NAME" \
        --project="$GCP_PROJECT" \
        --data-file="$CREDENTIALS_FILE"

    log_ok "Credentials pushed to Secret Manager (${SECRET_NAME})."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "============================================="
echo "  Project Cradle SoftAP Setup Complete"
echo "============================================="
echo "  SSID:      ${SSID}"
echo "  Password:  ${PASSWORD}"
echo "  Gateway:   ${AP_IP}"
echo "  Interface: ${WLAN_IFACE}"
echo "  Channel:   ${AP_CHANNEL}"
if [[ -n "$PROFILE_NAME" ]]; then
    echo "  Profile:   ${PROFILE_NAME}"
fi
echo "============================================="
echo ""
echo "The ESP32 firmware can retrieve these credentials"
echo "from GCP Secret Manager during the build/flash step."
echo ""
