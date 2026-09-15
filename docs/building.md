# Build the kernel and boot images

This document describes the current development build for POCO F4 (`munch`). The repository is not yet a one-command clean-clone build: the kernel source, cross-toolchain, static BusyBox binary and generated initramfs payloads must be supplied separately.

## Build inputs

The existing scripts expect this local layout:

```text
source/linux-6.19.6/
toolchains/gcc-13.2.0-nolibc/aarch64-linux/
toolchains/extra/usr/
out/mainline_munch/initramfs.cpio.gz
```

These paths are excluded by `.gitignore`. A successful build on one developer's workstation does not prove that a clean clone is reproducible.

Record checksums and download sources for every input used in a release.

## Host requirements

A Linux build host needs the normal kernel build dependencies, including:

```text
make, gcc, binutils, bc, bison, flex, openssl development files,
libelf development files, device-tree-compiler, cpio, gzip, tar and Python 3
```

The checked-in `toolchains/setup_env.sh` expects a specific local GCC 13 cross-toolchain and an auxiliary `toolchains/extra` prefix. Either reproduce that layout or update the environment script in a dedicated change and document the new toolchain.

## Prepare the Linux source tree

Place the exact Linux 6.19.6 source used by the release in `source/linux-6.19.6`. Copy the device tree into the kernel tree:

```bash
cp dts/sm8250-xiaomi-munch.dts \
  source/linux-6.19.6/arch/arm64/boot/dts/qcom/
```

The Qualcomm DTB Makefile must include:

```make
dtb-$(CONFIG_ARCH_QCOM) += sm8250-xiaomi-munch.dtb
DTC_FLAGS_sm8250-xiaomi-munch := -@
```

The current repository contains the final DTS but not a complete patch series for the kernel source and configuration. Converting the local kernel changes into reviewable patches is a high-priority reproducibility task.

## Kernel configuration

The reference kernel release suffix is:

```text
-munch-ubuntu
```

Important configuration areas include devtmpfs, cgroups v2, namespaces, overlayfs, Qualcomm SM8250 support, UFS, USB ConfigFS gadget functions, PCIe and `ath11k`.

The checked-in `extracted_config.txt` was extracted from the legacy Android kernel and is **not** the Mainline 6.19.6 configuration. Do not use it as the Mainline defconfig. The project still needs to check in a maintained Mainline config fragment or defconfig.

Before release, save the effective configuration and compare it with the expected snapshot:

```bash
make -C source/linux-6.19.6 ARCH=arm64 savedefconfig
sha256sum source/linux-6.19.6/.config
```

## Compile

After the expected source and toolchain paths exist:

```bash
./scripts/mainline/compile_kernel.sh
```

The script builds:

```text
out/mainline_munch/Image
out/mainline_munch/sm8250-xiaomi-munch.dtb
out/mainline_munch/modules/
```

Check the DTB before packaging:

```bash
dtc -I dtb -O dts out/mainline_munch/sm8250-xiaomi-munch.dtb \
  | grep -A2 'qcom,board-id'
```

## Assemble the initramfs

The packaging script requires `out/mainline_munch/initramfs.cpio.gz`, but the compile script does not create it. The archive must contain at least:

```text
/init
/bin/busybox
/dev
/proc
/sys
/sysroot
/opt/modules.tar.gz
/opt/ath11k_firmware.tar.gz
```

Use `initramfs/init_mainline_munch` as `/init`, preserve executable permissions and use a statically linked ARM64 BusyBox. The modules archive must install into `lib/modules/6.19.6-munch-ubuntu/`, and the firmware archive must install into `ath11k/QCA6390/hw2.0/`.

A typical archive command, run from the prepared initramfs directory, is:

```bash
find . -print0 | cpio --null -o --format=newc | gzip -9 \
  > ../initramfs.cpio.gz
```

Do not use a host-architecture BusyBox binary. Test it with `file` before packaging.

## Package Android boot images

Once all three inputs exist:

```text
out/mainline_munch/Image
out/mainline_munch/sm8250-xiaomi-munch.dtb
out/mainline_munch/initramfs.cpio.gz
```

run:

```bash
./scripts/mainline/package_boot_images.sh
```

This produces:

```text
debian_mainline_boot_munch.img
debian_mainline_vendor_boot_munch.img
debian_mainline_single_boot_munch.img
```

The historical `debian_` prefix is retained for compatibility even though the current userspace is Ubuntu. New release tooling should migrate to neutral `baredroid-*` artifact names with a compatibility note.

## Verify artifacts

Inspect and hash every output:

```bash
python3 unpack_bootimg.py --boot_img debian_mainline_boot_munch.img \
  --out inspect/boot
python3 unpack_bootimg.py --boot_img debian_mainline_vendor_boot_munch.img \
  --out inspect/vendor_boot
sha256sum debian_mainline_*_munch.img
```

Also verify that the packaged DTB, module archive and kernel all came from the same build directory.

## Test strategy

If the installed bootloader accepts temporary boot images, start with:

```bash
./scripts/test_mainline_munch.sh
```

Temporary boot is not guaranteed to exercise the exact `boot_b` plus `vendor_boot_b` path. Keep partition backups even after a successful RAM boot test.

For release validation, record:

- Fastboot product and bootloader version.
- Exact phone variant and storage capacity.
- Kernel log from boot to systemd.
- USB gadget connectivity.
- Root filesystem mount source.
- Wi-Fi association and firmware versions.
- Reboot to slot A and return to slot B.

## Known build-system gaps

- No automated kernel/toolchain download with checksum verification.
- No maintained kernel patch series or source submodule.
- No script that assembles the Mainline initramfs from a clean clone.
- No automated Ubuntu rootfs builder or package manifest.
- No CI job that rebuilds and compares release artifacts.

Documentation should continue to state these limits until the corresponding tooling is added and tested.
