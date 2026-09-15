#!/usr/bin/env bash
# ==============================================================================
# 02_backup_partitions.sh - Backup de Particiones Críticas del POCO F4 (munch)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="${BASE_DIR}/backups/$(date +%Y%m%d_%H%M%S)"
PLATFORM_TOOLS="${BASE_DIR}/platform-tools"

if [ -d "${PLATFORM_TOOLS}" ]; then
    export PATH="${PLATFORM_TOOLS}:${PATH}"
fi

FASTBOOT="$(command -v fastboot || true)"
ADB="$(command -v adb || true)"

mkdir -p "${BACKUP_DIR}"

echo "=========================================================="
echo "    POCO F4 (munch) - Respaldo de Particiones Críticas   "
echo "=========================================================="
echo "Directorio de respaldo: ${BACKUP_DIR}"
echo ""

# Lista de particiones críticas e irremplazables de Qualcomm (calibración RF, IMEI, MAC, DRM)
CRITICAL_PARTS=(
    "modemst1"
    "modemst2"
    "fsg"
    "fsc"
    "persist"
    "devinfo"
    "boot_a"
    "boot_b"
    "dtbo_a"
    "dtbo_b"
    "vbmeta_a"
    "vbmeta_b"
)

# 1. Comprobar si hay dispositivo en ADB (idealmente TWRP / Recovery con root)
if [ -n "${ADB}" ] && [ -n "$("${ADB}" devices | sed '1d' | grep -v '^$')" ]; then
    echo "[+] Dispositivo detectado vía ADB."
    echo "[*] Verificando permisos de root en el dispositivo..."
    
    IS_ROOT=$("${ADB}" shell "id -u" 2>/dev/null || echo "not-root")
    if [ "${IS_ROOT}" != "0" ]; then
        echo "[!] ADB no tiene permisos de root directo. Intentando 'su'..."
    fi

    echo "[*] Extrayendo particiones mediante ADB..."
    for part in "${CRITICAL_PARTS[@]}"; do
        echo "    -> Respaldando '${part}'..."
        "${ADB}" shell "dd if=/dev/block/by-name/${part} of=/tmp/${part}.img status=none 2>/dev/null || dd if=/dev/block/bootdevice/by-name/${part} of=/tmp/${part}.img status=none" || true
        "${ADB}" pull "/tmp/${part}.img" "${BACKUP_DIR}/${part}.img" 2>/dev/null || true
        "${ADB}" shell "rm -f /tmp/${part}.img" 2>/dev/null || true
    done
    echo "[+] Proceso de respaldo vía ADB finalizado en: ${BACKUP_DIR}"
    exit 0
fi

# 2. Si está en Fastboot
if [ -n "${FASTBOOT}" ] && [ -n "$("${FASTBOOT}" devices)" ]; then
    echo "[+] Dispositivo detectado en Fastboot."
    echo "[*] Nota: El bootloader de fábrica de Xiaomi limita la lectura cruda de particiones por fastboot."
    echo "    Probando si 'fastboot fetch' está habilitado para particiones de arranque..."
    
    for part in "boot_a" "boot_b" "dtbo_a" "dtbo_b"; do
        echo "    -> Intentando extraer ${part}..."
        "${FASTBOOT}" fetch "${part}" "${BACKUP_DIR}/${part}.img" 2>/dev/null || echo "       [!] 'fastboot fetch' no disponible en este ABL para '${part}'."
    done

    echo ""
    echo "[!] Para respaldar las particiones críticas de radiofrecuencia (modemst1/persist):"
    echo "    Se recomienda iniciar temporalmente TWRP u OrangeFox vía fastboot:"
    echo "    fastboot boot twrp-munch.img"
    echo "    Y luego ejecutar nuevamente este script."
    exit 0
fi

echo "[-] No se detectó el POCO F4 por USB. Conéctalo en Fastboot o Recovery."
exit 1
