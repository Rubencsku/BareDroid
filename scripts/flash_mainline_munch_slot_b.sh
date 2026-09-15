#!/usr/bin/env bash
set -e

# POCO F4 (munch) - Flash Mainline Linux 6.19.6 for Munch to Slot B
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASEDIR"

FASTBOOT="./platform-tools/fastboot"
if ! command -v "$FASTBOOT" >/dev/null 2>&1; then
    FASTBOOT="fastboot"
fi

BOOT_IMG="debian_mainline_boot_munch.img"
VENDOR_BOOT_IMG="debian_mainline_vendor_boot_munch.img"

if [ ! -f "$BOOT_IMG" ] || [ ! -f "$VENDOR_BOOT_IMG" ]; then
    echo "[-] Error: Boot images not found! Run ./scripts/mainline/package_boot_images.sh first."
    exit 1
fi

echo "=========================================================="
echo "   POCO F4 (munch) - Flasheo de Mainline Linux a Slot B   "
echo "=========================================================="
echo "[*] Ranura A (LineageOS / Stock): INTACTA"
echo "[*] Ranura B (Ubuntu Server): SERÁ ACTUALIZADA A MAINLINE"
echo ""

echo "[*] Esperando dispositivo en modo Fastboot..."
while true; do
    DEVICE=$("$FASTBOOT" devices 2>/dev/null | awk '{print $1}')
    if [ -n "$DEVICE" ]; then
        echo "[+] Dispositivo Fastboot detectado: $DEVICE"
        break
    fi
    sleep 1
done

echo "[*] Paso 1: Borrando dtbo_b para evitar interferencia del overlay 4.19 con el DTB Mainline..."
"$FASTBOOT" erase dtbo_b

echo "[*] Paso 2: Flasheando boot_b con $BOOT_IMG..."
"$FASTBOOT" flash boot_b "$BOOT_IMG"

echo "[*] Paso 3: Flasheando vendor_boot_b con $VENDOR_BOOT_IMG..."
"$FASTBOOT" flash vendor_boot_b "$VENDOR_BOOT_IMG"

echo "[*] Paso 4: Asegurando que la ranura activa sea B..."
"$FASTBOOT" --set-active=b

echo ""
echo "[+] Flasheo completado con éxito!"
echo "[*] Reiniciando dispositivo en Ubuntu 26.04 + Mainline Linux 6.19.6..."
"$FASTBOOT" reboot
