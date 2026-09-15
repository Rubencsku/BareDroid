#!/usr/bin/env bash
set -e

# Connect to the BareDroid target over USB or Wi-Fi.
# Usage:
#   ./scripts/connect_phone.sh usb
#   ./scripts/connect_phone.sh wifi [host-or-address]

MODE="${1:-wifi}"

if [ "$MODE" = "usb" ]; then
    TARGET_HOST="172.16.42.1"
    echo "[*] Connecting through USB Gadget Ethernet ($TARGET_HOST)..."
elif [ "$MODE" = "wifi" ]; then
    TARGET_HOST="${2:-${BAREDROID_HOST:-poco-server.local}}"
    echo "[*] Connecting through Wi-Fi ($TARGET_HOST)..."
else
    echo "Usage: $0 [usb|wifi] [host-or-address]" >&2
    exit 2
fi

exec ssh -o StrictHostKeyChecking=accept-new "root@$TARGET_HOST"
