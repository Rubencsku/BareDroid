#!/usr/bin/env bash
set -e

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$BASEDIR"

echo "=== Building Mainline Linux 6.19.6 for POCO F4 (munch) ==="
source toolchains/setup_env.sh

cd source/linux-6.19.6

NPROC=$(nproc 2>/dev/null || echo 8)
echo "[*] Compiling kernel Image with $NPROC jobs..."
make -j"$NPROC" Image

echo "[*] Compiling Device Tree Blob..."
make qcom/sm8250-xiaomi-munch.dtb

echo "[*] Compiling Kernel Modules..."
make -j"$NPROC" modules

echo "[+] Compilation successful!"
mkdir -p "$BASEDIR/out/mainline_munch"
cp -v arch/arm64/boot/Image "$BASEDIR/out/mainline_munch/Image"
cp -v arch/arm64/boot/dts/qcom/sm8250-xiaomi-munch.dtb "$BASEDIR/out/mainline_munch/sm8250-xiaomi-munch.dtb"

echo "[*] Installing modules to out/mainline_munch/modules..."
make modules_install INSTALL_MOD_PATH="$BASEDIR/out/mainline_munch/modules" INSTALL_MOD_STRIP=1

echo "[+] Finished! Artifacts in $BASEDIR/out/mainline_munch:"
ls -lh "$BASEDIR/out/mainline_munch"
