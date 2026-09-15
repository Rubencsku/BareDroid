#!/usr/bin/env bash
set -e

# POCO F4 (munch) - Flash Mainline Linux 6.19.6 + Native Systemd to Slot B
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASEDIR"

FASTBOOT="./platform-tools/fastboot"
if ! command -v "$FASTBOOT" >/dev/null 2>&1; then
    FASTBOOT="fastboot"
fi

echo "[*] Waiting for device in Fastboot mode..."
while true; do
    DEVICE=$("$FASTBOOT" devices 2>/dev/null | awk '{print $1}')
    if [ -n "$DEVICE" ]; then
        echo "[+] Fastboot device detected: $DEVICE"
        break
    fi
    sleep 1
done

echo "[*] Step 1: Erasing dtbo_b to prevent Android 4.19 overlay corruption on Mainline DTB..."
"$FASTBOOT" erase dtbo_b

echo "[*] Step 2: Flashing boot_b with debian_619_boot.img (Mainline 6.19.6)..."
"$FASTBOOT" flash boot_b debian_619_boot.img

echo "[*] Step 3: Flashing vendor_boot_b with debian_619_vendor_boot.img..."
"$FASTBOOT" flash vendor_boot_b debian_619_vendor_boot.img

echo "[*] Step 4: Ensuring active slot is B..."
"$FASTBOOT" --set-active=b

echo "[+] Flashing complete! Rebooting device into Ubuntu 26.04 Mainline + Systemd..."
"$FASTBOOT" reboot
