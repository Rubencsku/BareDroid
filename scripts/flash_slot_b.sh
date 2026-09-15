#!/usr/bin/env bash
set -e

# POCO F4 (munch) - Flash Debian 12 ARM64 Images to Slot B
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASEDIR"

FASTBOOT="./platform-tools/fastboot"
if ! command -v "$FASTBOOT" >/dev/null 2>&1; then
    FASTBOOT="fastboot"
fi

echo "[*] Checking Fastboot connection..."
"$FASTBOOT" devices

echo "[*] Flashing boot_b with debian_419_boot_v11.img..."
"$FASTBOOT" flash boot_b debian_419_boot_v11.img

echo "[*] Flashing vendor_boot_b with debian_419_vendor_boot_v11.img..."
"$FASTBOOT" flash vendor_boot_b debian_419_vendor_boot_v11.img

echo "[*] Setting active slot to B..."
"$FASTBOOT" --set-active=b

echo "[+] Flashing complete! Rebooting device..."
"$FASTBOOT" reboot
