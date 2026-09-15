#!/usr/bin/env bash
# ==============================================================================
# 04_prepare_debian_installer.sh - Descarga y Creación de USB Instalador Debian ARM64
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ISO_DIR="${BASE_DIR}/iso"
mkdir -p "${ISO_DIR}"

DEBIAN_ISO_URL="https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/debian-13.6.0-arm64-netinst.iso"
ISO_NAME="$(basename "${DEBIAN_ISO_URL}")"
LOCAL_ISO="${ISO_DIR}/${ISO_NAME}"

echo "=========================================================="
echo "   Preparador de Instalador Debian 13 (ARM64) en USB OTG  "
echo "=========================================================="
echo ""

# 1. Descargar la ISO si no existe
if [ ! -f "${LOCAL_ISO}" ]; then
    echo "[*] Descargando imagen oficial Debian ARM64 (${ISO_NAME})..."
    curl -L --progress-bar -o "${LOCAL_ISO}" "${DEBIAN_ISO_URL}"
    echo "[+] Descarga completada: ${LOCAL_ISO}"
else
    echo "[+] Imagen Debian ARM64 ya descargada: ${LOCAL_ISO}"
fi

echo ""
echo "[*] Dispositivos de almacenamiento detectados en el sistema:"
lsblk -d -e 7,11 -o NAME,SIZE,MODEL,TRAN,RM,HOTPLUG
echo ""

echo "Por favor conecta tu pendrive USB (que conectarás luego al POCO F4 vía USB OTG)."
read -rp "Ingresa el nombre del dispositivo de destino (ejemplo: sdb, sdc - ¡SIN NÚMERO DE PARTICIÓN!): " DEV_NAME

if [ -z "${DEV_NAME}" ]; then
    echo "Operación cancelada."
    exit 0
fi

TARGET_DEV="/dev/${DEV_NAME}"

if [ ! -b "${TARGET_DEV}" ]; then
    echo "[-] Error: El dispositivo '${TARGET_DEV}' no existe."
    exit 1
fi

# Seguridad para evitar sobrescribir el disco principal
if [ "${DEV_NAME}" = "sda" ] || [ "${DEV_NAME}" = "nvme0n1" ]; then
    echo "[-] ADVERTENCIA CRÍTICA: Has seleccionado '${DEV_NAME}', que suele ser el disco principal de tu PC."
    read -rp "¿Estás COMPLETAMENTE seguro de que quieres destruir ${TARGET_DEV}? (escribe 'SOBRESCRIBIR'): " CONFIRM_DANGER
    if [ "${CONFIRM_DANGER}" != "SOBRESCRIBIR" ]; then
        echo "Operación abortada por seguridad."
        exit 1
    fi
fi

echo ""
echo "[!] ATENCIÓN: Todos los datos en ${TARGET_DEV} serán eliminados permanentemente."
read -rp "¿Confirmas la escritura de Debian ARM64 en ${TARGET_DEV}? (s/n): " CONFIRM

if [ "${CONFIRM}" != "s" ] && [ "${CONFIRM}" != "si" ] && [ "${CONFIRM}" != "y" ]; then
    echo "Operación cancelada."
    exit 0
fi

echo "[*] Desmontando particiones de ${TARGET_DEV} si están montadas..."
sudo umount "${TARGET_DEV}"* 2>/dev/null || true

echo "[*] Grabando Debian ARM64 en ${TARGET_DEV}..."
sudo dd if="${LOCAL_ISO}" of="${TARGET_DEV}" bs=4M status=progress oflag=sync

echo ""
echo "[+] ¡Pendrive USB de instalación Debian ARM64 creado exitosamente!"
echo ""
echo "Siguientes pasos para la instalación en el POCO F4:"
echo " 1. Conecta este pendrive al POCO F4 utilizando un adaptador o hub USB-C OTG."
echo " 2. (Recomendado) Conecta también un teclado USB o un hub USB con teclado y pendrive."
echo " 3. Enciende el POCO F4. El firmware EDK2 UEFI detectará el pendrive e iniciará el instalador de Debian."
echo " 4. Si aparece el menú de UEFI, presiona la tecla de Subir Volumen (Volume Up) para seleccionar el arranque desde el pendrive USB."
