#!/bin/bash

# Wait a bit on startup to let PPP fully establish
echo "Waiting for network to stabilize..."
sleep 15

# Always run fix on startup (handles boot scenario)
echo "Running initial RFC4638 check..."
/data/unifi-rfc4638/rfc4638-mtu.sh

# Start monitoring for changes
echo "Starting MTU monitoring for ppp0..."
ip monitor link | while read -r line; do
  # Only trigger if ppp0 is UP and has MTU change
  if [[ "$line" == *"ppp0"* && "$line" == *"UP"* && "$line" == *"mtu"* ]]; then
    # Extract MTU value from the line
    if [[ "$line" =~ mtu[[:space:]]([0-9]+) ]]; then
      MTU="${BASH_REMATCH[1]}"
      # Only run script if MTU is wrong
      if [ "$MTU" -eq 1492 ]; then
        echo "MTU change detected on ppp0: MTU is $MTU, fixing..."
        /data/unifi-rfc4638/rfc4638-mtu.sh
      fi
    fi
  fi
done
