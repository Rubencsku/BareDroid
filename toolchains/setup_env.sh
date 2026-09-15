#!/usr/bin/env bash
# Setup environment for ARM64 kernel compilation
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export ARCH=arm64
export CROSS_COMPILE="$BASEDIR/toolchains/gcc-13.2.0-nolibc/aarch64-linux/bin/aarch64-linux-"
export PATH="$BASEDIR/toolchains/gcc-13.2.0-nolibc/aarch64-linux/bin:$BASEDIR/toolchains/extra/usr/bin:$PATH"
export M4="$BASEDIR/toolchains/extra/usr/bin/m4"
export BISON_PKGDATADIR="$BASEDIR/toolchains/extra/usr/share/bison"

export CPATH="$BASEDIR/toolchains/extra/usr/include:${CPATH:-}"
export LIBRARY_PATH="$BASEDIR/toolchains/extra/usr/lib/x86_64-linux-gnu:${LIBRARY_PATH:-}"
export LD_LIBRARY_PATH="$BASEDIR/toolchains/extra/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="$BASEDIR/toolchains/extra/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"

echo "[+] ARM64 Kernel build environment loaded:"
echo "    ARCH: $ARCH"
echo "    CROSS_COMPILE: $CROSS_COMPILE"
echo "    GCC: $("${CROSS_COMPILE}gcc" --version | head -n 1)"
echo "    DTC: $(dtc --version)"
echo "    BISON: $(bison --version | head -n 1)"
echo "    M4: $(m4 --version | head -n 1)"
