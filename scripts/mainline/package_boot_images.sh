#!/usr/bin/env bash
set -e

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$BASEDIR"

echo "=== Packaging Mainline Linux 6.19.6 Boot Images for POCO F4 (munch) ==="

KERNEL="out/mainline_munch/Image"
DTB="out/mainline_munch/sm8250-xiaomi-munch.dtb"
INITRAMFS="out/mainline_munch/initramfs.cpio.gz"

if [ ! -f "$KERNEL" ] || [ ! -f "$DTB" ] || [ ! -f "$INITRAMFS" ]; then
    echo "[-] Error: Missing required build artifacts!"
    exit 1
fi

CMDLINE="console=tty0 console=ttyMSM0,115200 earlycon androidboot.hardware=qcom root=/dev/sda34 rw rootwait rootfstype=ext4 swiotlb=2048 loop.max_part=7 systemd.journald.forward_to_console=1"

echo "[*] Step 1: Building debian_mainline_boot_munch.img (Android Header v3)..."
python3 mkbootimg.py \
    --header_version 3 \
    --os_version 14.0.0 \
    --os_patch_level 2025-01 \
    --kernel "$KERNEL" \
    --ramdisk "$INITRAMFS" \
    --pagesize 4096 \
    -o out/mainline_munch/debian_mainline_boot_munch.img

echo "[*] Step 2: Building debian_mainline_vendor_boot_munch.img (Android Header v3)..."
python3 mkbootimg.py \
    --header_version 3 \
    --pagesize 4096 \
    --base 0 \
    --kernel_offset 0x8000 \
    --ramdisk_offset 0x1000000 \
    --tags_offset 0x100 \
    --dtb_offset 0x1f00000 \
    --vendor_cmdline "$CMDLINE" \
    --vendor_ramdisk "$INITRAMFS" \
    --dtb "$DTB" \
    --vendor_boot out/mainline_munch/debian_mainline_vendor_boot_munch.img

echo "[*] Step 3: Building debian_mainline_single_boot_munch.img (Appended DTB for 'fastboot boot')..."
cat "$KERNEL" "$DTB" > out/mainline_munch/Image_dtb_appended
python3 mkbootimg.py \
    --header_version 0 \
    --pagesize 4096 \
    --base 0 \
    --kernel_offset 0x8000 \
    --ramdisk_offset 0x1000000 \
    --tags_offset 0x100 \
    --cmdline "$CMDLINE" \
    --kernel out/mainline_munch/Image_dtb_appended \
    --ramdisk "$INITRAMFS" \
    -o out/mainline_munch/debian_mainline_single_boot_munch.img

# Copy to root directory for easy access
cp -v out/mainline_munch/debian_mainline_boot_munch.img debian_mainline_boot_munch.img
cp -v out/mainline_munch/debian_mainline_vendor_boot_munch.img debian_mainline_vendor_boot_munch.img
cp -v out/mainline_munch/debian_mainline_single_boot_munch.img debian_mainline_single_boot_munch.img

echo "[+] Boot packaging complete! Generated images:"
ls -lh debian_mainline_*boot_munch.img
