# BareDroid boot architecture

This document describes the current POCO F4 (`munch`) implementation. It is not a generic recipe for every Android phone.

## Boot chain

```text
Qualcomm boot ROM and firmware
        ↓
Xiaomi Android Bootloader (ABL)
        ↓
slot B: boot_b + vendor_boot_b
        ↓
Linux Mainline 6.19.6 + munch DTB
        ↓
BareDroid BusyBox initramfs
        ↓
ext4 root filesystem on userdata
        ↓
systemd as PID 1
```

Slot A is intentionally left for Android or another known-good system. Slot B contains the BareDroid boot images. Userdata is shared storage at the bootloader level but is reformatted as an ext4 Linux root filesystem in the reference setup.

## Android boot images

The reference build uses Android boot image header version 3:

- `boot_b` contains the Linux kernel and a ramdisk.
- `vendor_boot_b` contains the vendor ramdisk, kernel command line and device tree.

The packaging script is `scripts/mainline/package_boot_images.sh`. It also creates a header-v0 image with the DTB appended for `fastboot boot` testing. Whether a bootloader accepts temporary boot images is device and firmware dependent.

## Device tree selection

The POCO F4 device tree lives at `dts/sm8250-xiaomi-munch.dts`. The important ABL selection property is:

```dts
qcom,board-id = <50 0>, <0 0>;
```

The kernel DTB Makefile also applies:

```make
DTC_FLAGS_sm8250-xiaomi-munch := -@
```

The `-@` option emits symbols used by overlay processing. The current boot flow erases `dtbo_b` because Android's slot-B overlay is not compatible with the Mainline device tree. The original DTBO must be backed up before this operation if slot-B restoration is required.

## Kernel command line

The current packaging script uses:

```text
console=tty0 console=ttyMSM0,115200 earlycon androidboot.hardware=qcom
root=/dev/sda34 rw rootwait rootfstype=ext4 swiotlb=2048
loop.max_part=7 systemd.journald.forward_to_console=1
```

`root=/dev/sda34` is specific to the tested layout. A future multi-device design should generate the command line from per-device metadata and prefer a stable PARTUUID or filesystem UUID.

## Initramfs responsibilities

`initramfs/init_mainline_munch` performs the early boot sequence:

1. Installs BusyBox applets and mounts `/dev`, `/proc` and `/sys`.
2. Creates an RNDIS or ECM USB Ethernet gadget.
3. Assigns `172.16.42.1/24` to the gadget interface.
4. Starts the emergency Telnet shell.
5. Locates and mounts the ext4 root filesystem.
6. Deploys matching kernel modules and QCA6390 firmware when embedded.
7. Writes a persistent networkd configuration for the USB interface.
8. Moves the virtual filesystems and calls `switch_root`.

The rescue Telnet daemon is useful during bring-up but has no authentication or encryption in the current implementation. It should become an explicit debug build option before BareDroid is considered suitable for broader deployment.

## Networking

### USB gadget

The initramfs attempts RNDIS first and ECM as a fallback. The phone normally uses `172.16.42.1/24`; the host should use another address in that subnet, conventionally `172.16.42.2/24`.

### Wi-Fi

The Mainline kernel exposes the QCA6390 through PCIe and `ath11k_pci`, normally as `wlp1s0`. Firmware is loaded from:

```text
/lib/firmware/ath11k/QCA6390/hw2.0/
```

This is different from the legacy Android-kernel path, which depended on Android partitions, Qualcomm daemons and a `wlan0` interface. Those scripts remain for historical reference and must not be confused with the current Mainline path.

## Repository boundary

Git stores the device-specific source and helper scripts. It does not store the complete kernel source tree, cross-toolchain, rootfs images, personal backups or generated boot images. Published releases are the distribution boundary for generated boot artifacts.

For a reproducible source release, each release should record:

- BareDroid commit.
- Linux source version and commit or tarball checksum.
- Kernel configuration checksum.
- Toolchain identity and version.
- Rootfs source archive and package manifest.
- Firmware provenance and checksums.
- Commands used to assemble the initramfs and boot images.
