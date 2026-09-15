#!/usr/bin/env bash
set -e

# POCO F4 (munch) - Rollback to Stable Kernel 4.19 + Initramfs v11
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

echo "[*] Step 1: Restoring dtbo_b from backup..."
"$FASTBOOT" flash dtbo_b backups/20260910_165419/dtbo_b.img

echo "[*] Step 2: Flashing boot_b with debian_419_boot_v11.img..."
"$FASTBOOT" flash boot_b debian_419_boot_v11.img

echo "[*] Step 3: Flashing vendor_boot_b with debian_419_vendor_boot_v11.img..."
"$FASTBOOT" flash vendor_boot_b debian_419_vendor_boot_v11.img

echo "[*] Step 4: Ensuring active slot is B..."
"$FASTBOOT" --set-active=b

echo "[+] Rollback complete! Rebooting device into Kernel 4.19..."
"$FASTBOOT" reboot
