#!/bin/bash

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Source config file
# shellcheck source=config.conf
# shellcheck disable=SC1091
source "$CONFIG_FILE"

# Validate required variables
if [ -z "$WAN_INTERFACE" ] || [ -z "$VLAN_ID" ] || [ -z "$TARGET_MTU" ] || [ -z "$VLAN_MTU" ] || [ -z "$PHYSICAL_MTU" ] || [ -z "$PPP_INTERFACE" ]; then
    echo "Error: Missing required configuration variables"
    exit 1
fi

# Debug logging function
log_debug() {
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG] $1" >&2
    fi
}

log_debug "Starting MTU fix with config: WAN=$WAN_INTERFACE, VLAN=$VLAN_ID, TARGET_MTU=$TARGET_MTU"

MTUPATH="/sys/class/net/${PPP_INTERFACE}/mtu"

if ! [ -f "$MTUPATH" ]; then
    log_debug "PPP interface $PPP_INTERFACE not ready"
    echo "$PPP_INTERFACE device not ready"
    exit 0
fi

CURRENT_MTU=$(cat "$MTUPATH")
log_debug "Current MTU: $CURRENT_MTU"

if [ "$CURRENT_MTU" -eq 1492 ]; then
    echo "MTU for $PPP_INTERFACE is $CURRENT_MTU, changing to $TARGET_MTU"

    # Update PPP configuration
    sed -i "s/ 1492/ $TARGET_MTU/g" "/etc/ppp/peers/${PPP_INTERFACE}"
    log_debug "Updated PPP config"

    # Set interface MTUs
    ip link set dev "${WAN_INTERFACE}" mtu "$PHYSICAL_MTU"
    ip link set dev "${WAN_INTERFACE}.${VLAN_ID}" mtu "$VLAN_MTU"
    log_debug "Set ${WAN_INTERFACE} MTU to $PHYSICAL_MTU, ${WAN_INTERFACE}.${VLAN_ID} MTU to $VLAN_MTU"

    # Bounce the interface
    ifconfig "${WAN_INTERFACE}" down
    ifconfig "${WAN_INTERFACE}" up
    log_debug "Bounced interface $WAN_INTERFACE"

    # Restart PPP
    killall pppd
    log_debug "Restarted pppd"

    echo "MTU fix applied successfully"
else
    log_debug "MTU is already correct: $CURRENT_MTU"
    echo "MTU is OK"
fi
