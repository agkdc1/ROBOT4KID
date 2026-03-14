#!/usr/bin/env bash
# ==============================================================================
# Train Console RPi4 Setup — Auto-AP with ESP32 fallback
# Creates Wi-Fi hotspot (TRAIN_CONSOLE) or connects to ESP32 AP (TRAIN_CTRL)
# Idempotent: safe to run multiple times
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Configuration ---
AP_SSID="TRAIN_CONSOLE"
AP_PASS="console1234"
AP_IP="192.168.5.1"
AP_SUBNET="255.255.255.0"
DHCP_START="192.168.5.10"
DHCP_END="192.168.5.50"
DHCP_LEASE="24h"
WLAN_IFACE="wlan0"

ESP32_SSID="TRAIN_CTRL"
ESP32_PASS=""  # Set if ESP32 AP has a password

SERVICE_NAME="train_controller"
SERVICE_USER="pi"
CONTROLLER_SCRIPT="${SCRIPT_DIR}/train_controller.py"
VENV_DIR="${SCRIPT_DIR}/.venv"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[SETUP]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

# --- Check root ---
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (sudo)"
    exit 1
fi

# ==============================================================================
# 1. Install system packages
# ==============================================================================
log "Installing system packages..."
apt-get update -qq
apt-get install -y -qq \
    hostapd \
    dnsmasq \
    python3-venv \
    python3-pip \
    python3-dev \
    libsdl2-dev \
    libsdl2-image-dev \
    libsdl2-mixer-dev \
    libsdl2-ttf-dev \
    > /dev/null 2>&1

log "System packages installed."

# ==============================================================================
# 2. Python virtual environment and dependencies
# ==============================================================================
log "Setting up Python virtual environment..."
if [[ ! -d "${VENV_DIR}" ]]; then
    python3 -m venv "${VENV_DIR}"
fi
"${VENV_DIR}/bin/pip" install --quiet --upgrade pip
"${VENV_DIR}/bin/pip" install --quiet -r "${SCRIPT_DIR}/requirements.txt"
log "Python dependencies installed."

# ==============================================================================
# 3. Check for ESP32 train AP — fallback mode
# ==============================================================================
check_esp32_ap() {
    log "Scanning for ESP32 train AP (${ESP32_SSID})..."
    # Ensure wlan0 is up for scanning
    ip link set "${WLAN_IFACE}" up 2>/dev/null || true
    sleep 2

    if iw dev "${WLAN_IFACE}" scan 2>/dev/null | grep -q "${ESP32_SSID}"; then
        return 0  # Found
    fi
    return 1  # Not found
}

connect_to_esp32() {
    log "Connecting to ESP32 AP: ${ESP32_SSID}"

    # Stop hostapd/dnsmasq if running
    systemctl stop hostapd 2>/dev/null || true
    systemctl stop dnsmasq 2>/dev/null || true
    systemctl disable hostapd 2>/dev/null || true
    systemctl disable dnsmasq 2>/dev/null || true

    # Create wpa_supplicant config for ESP32
    local WPA_CONF="/etc/wpa_supplicant/wpa_supplicant-${WLAN_IFACE}.conf"
    cat > "${WPA_CONF}" <<WPAEOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="${ESP32_SSID}"
    $(if [[ -n "${ESP32_PASS}" ]]; then echo "psk=\"${ESP32_PASS}\""; else echo "key_mgmt=NONE"; fi)
    priority=10
}
WPAEOF

    # Use dhcpcd for dynamic IP from ESP32
    systemctl restart wpa_supplicant 2>/dev/null || true
    systemctl restart dhcpcd 2>/dev/null || true

    log "Connected to ESP32 AP (client mode)."
    return 0
}

# ==============================================================================
# 4. Configure hostapd (Access Point)
# ==============================================================================
setup_hostapd() {
    log "Configuring hostapd..."

    cat > /etc/hostapd/hostapd.conf <<HAPEOF
interface=${WLAN_IFACE}
driver=nl80211
ssid=${AP_SSID}
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${AP_PASS}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
HAPEOF

    # Point hostapd to config
    if grep -q "^#DAEMON_CONF" /etc/default/hostapd 2>/dev/null; then
        sed -i 's|^#DAEMON_CONF.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
    elif ! grep -q "DAEMON_CONF" /etc/default/hostapd 2>/dev/null; then
        echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd
    fi

    systemctl unmask hostapd 2>/dev/null || true
    log "hostapd configured."
}

# ==============================================================================
# 5. Configure dnsmasq (DHCP)
# ==============================================================================
setup_dnsmasq() {
    log "Configuring dnsmasq..."

    # Backup original if not already done
    if [[ -f /etc/dnsmasq.conf && ! -f /etc/dnsmasq.conf.orig ]]; then
        cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
    fi

    cat > /etc/dnsmasq.d/train_console.conf <<DNSEOF
interface=${WLAN_IFACE}
dhcp-range=${DHCP_START},${DHCP_END},${AP_SUBNET},${DHCP_LEASE}
domain=local
address=/train.local/${AP_IP}
DNSEOF

    log "dnsmasq configured."
}

# ==============================================================================
# 6. Configure static IP for AP mode
# ==============================================================================
setup_static_ip() {
    log "Configuring static IP for ${WLAN_IFACE}..."

    local DHCPCD_CONF="/etc/dhcpcd.conf"
    local MARKER="# TRAIN_CONSOLE_AP"

    # Remove old config block if present
    if grep -q "${MARKER}" "${DHCPCD_CONF}" 2>/dev/null; then
        sed -i "/${MARKER}/,/${MARKER}_END/d" "${DHCPCD_CONF}"
    fi

    cat >> "${DHCPCD_CONF}" <<IPEOF
${MARKER}
interface ${WLAN_IFACE}
    static ip_address=${AP_IP}/24
    nohook wpa_supplicant
${MARKER}_END
IPEOF

    log "Static IP configured: ${AP_IP}/24"
}

# ==============================================================================
# 7. Create systemd service for train_controller.py
# ==============================================================================
setup_service() {
    log "Creating systemd service: ${SERVICE_NAME}"

    cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<SVCEOF
[Unit]
Description=Train Console Controller
After=network.target
Wants=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${VENV_DIR}/bin/python ${CONTROLLER_SCRIPT}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1
Environment=SDL_VIDEODRIVER=kmsdrm
Environment=SDL_FBDEV=/dev/fb0

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}"
    log "Service ${SERVICE_NAME} enabled (auto-start on boot)."
}

# ==============================================================================
# 8. Enable SPI (for MCP3008)
# ==============================================================================
setup_spi() {
    log "Enabling SPI interface..."

    if ! grep -q "^dtparam=spi=on" /boot/config.txt 2>/dev/null && \
       ! grep -q "^dtparam=spi=on" /boot/firmware/config.txt 2>/dev/null; then
        # Try both locations (Raspberry Pi OS Bullseye vs Bookworm)
        local BOOT_CFG=""
        if [[ -f /boot/firmware/config.txt ]]; then
            BOOT_CFG="/boot/firmware/config.txt"
        elif [[ -f /boot/config.txt ]]; then
            BOOT_CFG="/boot/config.txt"
        fi

        if [[ -n "${BOOT_CFG}" ]]; then
            echo "dtparam=spi=on" >> "${BOOT_CFG}"
            log "SPI enabled in ${BOOT_CFG} (reboot required)."
        else
            warn "Could not find boot config. Enable SPI manually via raspi-config."
        fi
    else
        log "SPI already enabled."
    fi
}

# ==============================================================================
# Main
# ==============================================================================
main() {
    log "=========================================="
    log "Train Console RPi4 Setup"
    log "=========================================="

    setup_spi

    # Check if ESP32 AP is available — if so, connect as client
    if check_esp32_ap; then
        warn "ESP32 train AP (${ESP32_SSID}) detected!"
        warn "Connecting as client instead of creating hotspot."
        connect_to_esp32
    else
        log "ESP32 AP not found. Creating hotspot: ${AP_SSID}"
        setup_hostapd
        setup_dnsmasq
        setup_static_ip

        # Start AP services
        systemctl restart dhcpcd
        systemctl start dnsmasq
        systemctl start hostapd

        log "Hotspot active: SSID=${AP_SSID}, IP=${AP_IP}"
    fi

    setup_service

    log "=========================================="
    log "Setup complete!"
    log "  Hotspot SSID: ${AP_SSID}"
    log "  Hotspot Pass: ${AP_PASS}"
    log "  Console IP:   ${AP_IP}"
    log "  Service:      sudo systemctl start ${SERVICE_NAME}"
    log "  Reboot recommended for SPI changes."
    log "=========================================="
}

main "$@"
