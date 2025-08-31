#!/bin/bash
set -e

# UniFi Dream Machine PPPoE MTU Fix Uninstaller
# Removes the MTU fix and restores original configuration

INSTALL_DIR="/data/unifi-rfc4638"
SERVICE_NAME="unifi-rfc4638.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

echo "=== UniFi Dream Machine RFC4638 Uninstaller ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

if [ ! -d "$INSTALL_DIR" ] && [ ! -f "$SERVICE_PATH" ]; then
    echo "UniFi RFC4638 does not appear to be installed."
    echo
    echo "Checked locations:"
    echo "  Service: $SERVICE_PATH"
    echo "  Install directory: $INSTALL_DIR"
    exit 0
fi

echo "This will remove the UniFi RFC4638 service and files."
echo "Your original PPPoE configuration will be restored."
echo

# Show what will be removed
echo "Will remove:"
if [ -f "$SERVICE_PATH" ]; then
    echo "  ✓ Service: $SERVICE_PATH"
fi
if [ -d "$INSTALL_DIR" ]; then
    echo "  ✓ Directory: $INSTALL_DIR"
fi
if [ -f /etc/ppp/peers/ppp0 ]; then
    if grep -q " 1500" /etc/ppp/peers/ppp0; then
        echo "  ✓ Restore PPPoE MTU from 1500 to 1492"
    fi
fi
echo

read -p "Continue with uninstall? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

echo "Stopping and disabling service..."
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl stop "$SERVICE_NAME"
    echo "  Service stopped"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl disable "$SERVICE_NAME"
    echo "  Service disabled"
fi

echo "Removing service file..."
if [ -f "$SERVICE_PATH" ]; then
    rm -f "$SERVICE_PATH"
    systemctl daemon-reload
    echo "  Service file removed"
fi

echo "Restoring original PPPoE MTU..."
if [ -f /etc/ppp/peers/ppp0 ]; then
    if grep -q " 1500" /etc/ppp/peers/ppp0; then
        sed -i 's/ 1500/ 1492/g' /etc/ppp/peers/ppp0
        echo "  PPPoE configuration restored to 1492 MTU"
    else
        echo "  PPPoE configuration already at default MTU"
    fi
else
    echo "  No PPPoE configuration found"
fi

echo "Removing installation directory..."
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "  Installation directory removed"
fi

echo
echo "=== Uninstall Complete ==="
echo
echo "UniFi RFC4638 has been completely removed."
echo
echo "Next steps:"
echo "  • Your PPPoE connection will use the default 1492 MTU"
echo "  • You may need to restart your PPPoE connection"
echo "  • Consider restarting the network service or rebooting"
echo "  • Re-enable MSS Clamping in UniFi settings if desired"
echo