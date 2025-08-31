#!/bin/bash

# Always run fix on startup (handles boot scenario)
echo "Running initial RFC4638 check..."
/data/unifi-rfc4638/rfc4638-mtu.sh

# Start monitoring for changes
echo "Starting MTU monitoring for ppp0..."
ip monitor link | while read -r line; do
  if [[ "$line" == *"ppp0"* && "$line" == *"mtu"* ]]; then
    echo "MTU change detected on ppp0: $line"
    /data/unifi-rfc4638/rfc4638-mtu.sh
  fi
done
