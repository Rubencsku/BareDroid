#!/usr/bin/env bash
# ==============================================================================
# 01_check_device.sh - POCO F4 (munch) Hardware & Fastboot Status Checker
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLATFORM_TOOLS="${BASE_DIR}/platform-tools"

if [ -d "${PLATFORM_TOOLS}" ]; then
    export PATH="${PLATFORM_TOOLS}:${PATH}"
fi

FASTBOOT="$(command -v fastboot || true)"
ADB="$(command -v adb || true)"

echo "=========================================================="
echo "    POCO F4 (munch) - Diagnóstico y Verificación USB     "
echo "=========================================================="

if [ -z "${FASTBOOT}" ]; then
    echo "[-] Error: 'fastboot' no encontrado en el sistema ni en platform-tools."
    exit 1
fi

echo "[*] Buscando dispositivos en modo Fastboot..."
FB_DEVICES=$("${FASTBOOT}" devices)

if [ -n "${FB_DEVICES}" ]; then
    echo "[+] Dispositivo detectado en modo Fastboot:"
    echo "${FB_DEVICES}"
    echo ""
    echo "[*] Consultando variables del bootloader..."
    
    PRODUCT=$("${FASTBOOT}" getvar product 2>&1 | grep "product:" | awk '{print $2}')
    UNLOCKED=$("${FASTBOOT}" getvar unlocked 2>&1 | grep "unlocked:" | awk '{print $2}')
    SLOT=$("${FASTBOOT}" getvar current-slot 2>&1 | grep "current-slot:" | awk '{print $2}')
    SLOT_COUNT=$("${FASTBOOT}" getvar slot-count 2>&1 | grep "slot-count:" | awk '{print $2}')
    
    echo "    - Modelo (Codename):   ${PRODUCT:-Desconocido}"
    echo "    - Bootloader Unlock:   ${UNLOCKED:-Desconocido}"
    echo "    - Slot Activo:         ${SLOT:-Desconocido}"
    echo "    - Cantidad de Slots:   ${SLOT_COUNT:-Desconocido}"
    echo ""

    if [ "${PRODUCT}" != "munch" ] && [ "${PRODUCT}" != "munch_in" ]; then
        echo "[!] ADVERTENCIA: El codename reportado '${PRODUCT}' no es 'munch'."
        echo "    Verifica que este dispositivo sea realmente un POCO F4 / Redmi K40S."
    else
        echo "[+] Confirmado: Dispositivo POCO F4 (munch) identificado correctamente."
    fi

    if [ "${UNLOCKED}" = "yes" ]; then
        echo "[+] Bootloader DESBLOQUEADO. Listo para flashear."
    else
        echo "[-] ERROR: El bootloader aparece como BLOQUEADO (${UNLOCKED})."
        echo "    Debes desbloquear el bootloader con Mi Unlock antes de continuar."
    fi
    exit 0
fi

echo "[*] No se encontró ningún dispositivo en Fastboot. Comprobando ADB..."
if [ -n "${ADB}" ]; then
    ADB_DEVICES=$("${ADB}" devices | sed '1d' | grep -v '^$' || true)
    if [ -n "${ADB_DEVICES}" ]; then
        echo "[+] Dispositivo detectado en modo ADB:"
        echo "${ADB_DEVICES}"
        echo ""
        echo "[*] Si deseas reiniciar a Fastboot, ejecuta:"
        echo "    ./platform-tools/adb reboot bootloader"
        exit 0
    fi
fi

echo "[-] No se detectó ningún dispositivo conectado por USB en Fastboot ni en ADB."
echo ""
echo "Instrucciones para entrar en modo Fastboot:"
echo " 1. Apaga el POCO F4 por completo."
echo " 2. Mantén presionados los botones [Bajar Volumen] + [Encendido] a la vez."
echo " 3. Suelta los botones cuando aparezca en pantalla el muñeco de Xiaomi o el texto 'FASTBOOT'."
echo " 4. Conecta el cable USB-C a la PC y vuelve a ejecutar este script."
exit 1
