#!/usr/bin/env bash
set -e

# POCO F4 (munch) - Live RAM Test of Mainline Linux 6.19.6 (NO FLASH)
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASEDIR"

FASTBOOT="./platform-tools/fastboot"
if ! command -v "$FASTBOOT" >/dev/null 2>&1; then
    FASTBOOT="fastboot"
fi

IMAGE="debian_mainline_single_boot_munch.img"
if [ ! -f "$IMAGE" ]; then
    echo "[-] Error: $IMAGE not found! Run ./scripts/mainline/package_boot_images.sh first."
    exit 1
fi

echo "=========================================================="
echo "    POCO F4 (munch) - Live RAM Boot Test (Mainline 6.19) "
echo "=========================================================="
echo "[!] Nota: Esta prueba carga el kernel directamente en la RAM."
echo "    NO escribe ni sobreescribe ninguna partición flash del teléfono."
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

echo "[*] Enviando y arrancando $IMAGE en memoria RAM..."
"$FASTBOOT" boot "$IMAGE"

echo ""
echo "[+] Kernel enviado a RAM con éxito!"
echo "[*] Una vez arranque, conecta el cable USB y verifica:"
echo "    ping 172.16.42.1"
echo "    ssh root@172.16.42.1"
echo "    telnet 172.16.42.1 23"
