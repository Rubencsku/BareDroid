#!/usr/bin/env bash
set -e

# POCO F4 (munch) - Boot and Vendor Boot Image Builder for Ubuntu ARM64
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASEDIR"

echo "[*] Building debian_initramfs_v11.cpio.gz..."
if [ -d "/tmp/new_initramfs_v11" ]; then
    (cd /tmp/new_initramfs_v11 && find . | cpio -H newc -o | gzip -9) > debian_initramfs_v11.cpio.gz
fi

echo "[*] Packaging debian_419_boot_v11.img..."
python3 mkbootimg.py \
    --header_version 3 \
    --os_version 14.0.0 \
    --os_patch_level 2025-01 \
    --kernel stock_boot_b_unpacked/kernel \
    --ramdisk debian_initramfs_v11.cpio.gz \
    --pagesize 4096 \
    -o debian_419_boot_v11.img

echo "[*] Packaging debian_419_vendor_boot_v11.img..."
python3 mkbootimg.py \
    --header_version 3 \
    --pagesize 4096 \
    --base 0 \
    --kernel_offset 0x8000 \
    --ramdisk_offset 0x1000000 \
    --tags_offset 0x100 \
    --dtb_offset 0x1f00000 \
    --vendor_cmdline "androidboot.hardware=qcom console=tty0 console=ttyMSM0,115200 root=/dev/sda34 rootwait rw init=/init androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 loop.max_part=7 cgroup.memory=nokmem,nosocket panic=0 firmware_class.path=/lib/firmware" \
    --vendor_ramdisk debian_initramfs_v11.cpio.gz \
    --dtb vendor_boot_unpacked/dtb \
    --vendor_boot debian_419_vendor_boot_v11.img

echo "[+] Boot images built successfully:"
ls -lh debian_419_boot_v11.img debian_419_vendor_boot_v11.img
