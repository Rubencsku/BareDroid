#!/usr/bin/env bash
# ==============================================================================
# 03_flash_uefi_bootloader.sh - Flasheo / Prueba del Firmware EDK2 UEFI en POCO F4
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
UEFI_IMG="${BASE_DIR}/boot-munch.img"
PLATFORM_TOOLS="${BASE_DIR}/platform-tools"

if [ -d "${PLATFORM_TOOLS}" ]; then
    export PATH="${PLATFORM_TOOLS}:${PATH}"
fi

FASTBOOT="$(command -v fastboot || true)"

echo "=========================================================="
echo "    POCO F4 (munch) - Instalador de Firmware EDK2 UEFI   "
echo "=========================================================="

if [ -z "${FASTBOOT}" ]; then
    echo "[-] Error: 'fastboot' no encontrado."
    exit 1
fi

if [ ! -f "${UEFI_IMG}" ]; then
    echo "[-] Error: No se encontró '${UEFI_IMG}'."
    exit 1
fi

echo "[*] Verificando conexión en modo Fastboot..."
FB_DEVICES=$("${FASTBOOT}" devices)
if [ -z "${FB_DEVICES}" ]; then
    echo "[-] Dispositivo no detectado. Pon el POCO F4 en modo Fastboot:"
    echo "    (Apagar -> Mantener presionado [Bajar Volumen] + [Power])"
    exit 1
fi

echo "[+] POCO F4 detectado en Fastboot:"
echo "${FB_DEVICES}"
echo ""

echo "Selecciona una opción:"
echo "  1) [PRUEBA SEGURA] Arrancar UEFI en RAM sin modificar la memoria interna (tethered boot)"
echo "  2) [FLASHEO PERMANENTE] Flashear UEFI en particiones de arranque (boot_a y boot_b)"
echo "  3) Cancelar"
echo ""

read -rp "Ingresa tu elección [1-3]: " CHOICE

case "${CHOICE}" in
    1)
        echo ""
        echo "[*] Enviando ${UEFI_IMG} a la memoria RAM del POCO F4..."
        "${FASTBOOT}" boot "${UEFI_IMG}"
        echo "[+] Imagen enviada con éxito. Observa la pantalla del POCO F4."
        echo "    Deberías ver la pantalla de inicio EDK2 UEFI y el menú de arranque."
        ;;
    2)
        echo ""
        echo "[!] ATENCIÓN: Vas a reemplazar el kernel de Android con el entorno EDK2 UEFI."
        read -rp "¿Estás completamente seguro de continuar? (escribe 'si' para confirmar): " CONFIRM
        if [ "${CONFIRM}" != "si" ] && [ "${CONFIRM}" != "s" ] && [ "${CONFIRM}" != "yes" ]; then
            echo "Operación cancelada."
            exit 0
        fi

        echo "[*] Limpiando particiones dtbo de Android que interfieren con UEFI..."
        "${FASTBOOT}" erase dtbo_a || true
        "${FASTBOOT}" erase dtbo_b || true

        echo "[*] Flasheando boot-munch.img en slot A..."
        "${FASTBOOT}" flash boot_a "${UEFI_IMG}"
        
        echo "[*] Flasheando boot-munch.img en slot B..."
        "${FASTBOOT}" flash boot_b "${UEFI_IMG}"

        echo "[*] Estableciendo slot A como activo..."
        "${FASTBOOT}" set_active a

        echo "[+] Flasheo completado con éxito."
        echo "¿Deseas reiniciar el dispositivo ahora? (s/n)"
        read -rp "> " REBOOT_NOW
        if [ "${REBOOT_NOW}" = "s" ] || [ "${REBOOT_NOW}" = "si" ] || [ "${REBOOT_NOW}" = "y" ]; then
            "${FASTBOOT}" reboot
            echo "[+] POCO F4 reiniciado. Ahora arrancará en el entorno Tianocore EDK2 UEFI."
        fi
        ;;
    *)
        echo "Operación cancelada."
        exit 0
        ;;
esac
