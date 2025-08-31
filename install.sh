#!/bin/bash
set -e

# UniFi Dream Machine PPPoE MTU Fix Installer
# Fixes RFC4638 MTU issues that UniFi web interface doesn't support

INSTALL_DIR="/data/unifi-rfc4638"
SERVICE_NAME="unifi-rfc4638.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Function to perform uninstall
uninstall() {
    echo "=== UniFi Dream Machine RFC4638 Uninstaller ==="
    echo

    if [ ! -d "$INSTALL_DIR" ] && [ ! -f "$SERVICE_PATH" ]; then
        echo "UniFi RFC4638 does not appear to be installed."
        exit 0
    fi

    echo "This will remove the UniFi RFC4638 service and files."
    echo "Your original PPPoE configuration will be restored."
    echo
    read -p "Continue with uninstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled"
        exit 0
    fi

    echo "Stopping and disabling service..."
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
    fi

    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SERVICE_NAME"
    fi

    echo "Removing service file..."
    if [ -f "$SERVICE_PATH" ]; then
        rm -f "$SERVICE_PATH"
        systemctl daemon-reload
    fi

    echo "Restoring original PPPoE MTU..."
    if [ -f /etc/ppp/peers/ppp0 ]; then
        sed -i 's/ 1500/ 1492/g' /etc/ppp/peers/ppp0
        echo "PPPoE configuration restored to 1492 MTU"
    fi

    echo "Removing installation directory..."
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi

    echo
    echo "=== Uninstall Complete ==="
    echo
    echo "UniFi RFC4638 has been completely removed."
    echo "You may need to restart your PPPoE connection for changes to take effect."
    echo "Consider restarting the network service or rebooting the device."

    exit 0
}

# Check for command line arguments
if [ "$1" = "--uninstall" ] || [ "$1" = "-u" ]; then
    uninstall
fi

echo "=== UniFi Dream Machine RFC4638 Installer ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Check if we're on a UniFi device
if ! [ -f /etc/default/unifi ]; then
    echo "Warning: This doesn't appear to be a UniFi Dream Machine"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Detecting network interfaces..."
echo "Available interfaces:"
ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | sed 's/^[0-9]*: \([^:]*\):.*/  \1/'
echo

# Auto-detect likely WAN interface
WAN_INTERFACE=$(ip route | grep default | head -1 | sed 's/.*dev \([^ ]*\).*/\1/' | cut -d'.' -f1)
if [ -n "$WAN_INTERFACE" ]; then
    echo "Detected likely WAN interface: $WAN_INTERFACE"
    read -p "Use $WAN_INTERFACE as WAN interface? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        WAN_INTERFACE=""
    fi
fi

if [ -z "$WAN_INTERFACE" ]; then
    read -p "Enter WAN interface name (e.g., eth4): " -r WAN_INTERFACE
fi

# Auto-detect VLAN from current PPPoE config
VLAN_ID=""
if [ -f /etc/ppp/peers/ppp0 ]; then
    VLAN_ID=$(grep -o "${WAN_INTERFACE}\.[0-9]*" /etc/ppp/peers/ppp0 2>/dev/null | cut -d'.' -f2 | tr -d '\n')
fi

if [ -n "$VLAN_ID" ]; then
    echo "Detected VLAN ID: $VLAN_ID"
    read -p "Use VLAN $VLAN_ID? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        VLAN_ID=""
    fi
fi

if [ -z "$VLAN_ID" ]; then
    read -p "Enter VLAN ID (e.g., 6): " -r VLAN_ID
fi

echo
echo "Configuration:"
echo "  WAN Interface: $WAN_INTERFACE"
echo "  VLAN ID: $VLAN_ID"
echo "  Install Directory: $INSTALL_DIR"
echo

read -p "Proceed with installation? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Installation cancelled"
    exit 0
fi

echo "Installing MTU fix..."

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download scripts from GitHub
echo "Downloading scripts from GitHub..."
GITHUB_BASE="https://raw.githubusercontent.com/rsanting/unifi-RFC4638/main"

curl -sSL "$GITHUB_BASE/rfc4638-mtu.sh" -o "$INSTALL_DIR/rfc4638-mtu.sh"
curl -sSL "$GITHUB_BASE/monitor-mtu.sh" -o "$INSTALL_DIR/monitor-mtu.sh"
curl -sSL "$GITHUB_BASE/uninstall.sh" -o "$INSTALL_DIR/uninstall.sh"
curl -sSL "$GITHUB_BASE/unifi-rfc4638.service" -o "$SERVICE_PATH"

# Generate configuration file
echo "Generating configuration..."
cat > "$INSTALL_DIR/config.conf" << EOF
# UniFi Dream Machine RFC4638 Configuration
#
# This file configures the RFC4638 enabler settings
# Edit this file to match your network configuration

# WAN interface (physical interface connected to your modem)
# Example: eth4, eth6, etc.
WAN_INTERFACE=$WAN_INTERFACE

# VLAN ID for PPPoE connection
# Check your ISP settings or UniFi configuration
VLAN_ID=$VLAN_ID

# Target MTU for PPPoE interface (usually 1500 for RFC4638)
TARGET_MTU=1500

# VLAN interface MTU (TARGET_MTU + 8 bytes PPPoE overhead)
VLAN_MTU=1508

# Physical interface MTU (VLAN_MTU + 4 bytes VLAN overhead)
PHYSICAL_MTU=1512

# PPPoE interface name (usually ppp0)
PPP_INTERFACE=ppp0

# Enable debug logging (true/false)
DEBUG=false

# Services to restart after MTU change
# Space-separated list of services
RESTART_SERVICES="dnscrypt-proxy dnsmasq"
EOF

# Make scripts executable
chmod +x "$INSTALL_DIR/rfc4638-mtu.sh"
chmod +x "$INSTALL_DIR/monitor-mtu.sh"
chmod +x "$INSTALL_DIR/uninstall.sh"

# Enable and start service
echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

echo
echo "=== Installation Complete ==="
echo
echo "UniFi RFC4638 has been installed and started as a systemd service."
echo
echo "Status commands:"
echo "  Check service status: systemctl status $SERVICE_NAME"
echo "  View logs: journalctl -u $SERVICE_NAME -f"
echo "  Stop service: systemctl stop $SERVICE_NAME"
echo "  Disable service: systemctl disable $SERVICE_NAME"
echo "  Uninstall: sudo bash $INSTALL_DIR/uninstall.sh"
echo "  Uninstall (alternative): sudo bash install.sh --uninstall"
echo
echo "Remember to disable MSS Clamping in the UniFi gateway interface settings!"
echo
echo "Current MTU status:"
if [ -f /sys/class/net/ppp0/mtu ]; then
    echo "  ppp0 MTU: $(cat /sys/class/net/ppp0/mtu)"
else
    echo "  ppp0 interface not found (may appear after PPPoE connection)"
fi

if [ -f "/sys/class/net/$WAN_INTERFACE/mtu" ]; then
    echo "  $WAN_INTERFACE MTU: $(cat "/sys/class/net/$WAN_INTERFACE/mtu")"
fi

if [ -f "/sys/class/net/$WAN_INTERFACE.$VLAN_ID/mtu" ]; then
    echo "  $WAN_INTERFACE.$VLAN_ID MTU: $(cat "/sys/class/net/$WAN_INTERFACE.$VLAN_ID/mtu")"
fi
