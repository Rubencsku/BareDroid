# BareDroid practical tutorial

This tutorial walks through the current BareDroid workflow for a Xiaomi POCO F4 / Redmi K40S (`munch`). It focuses on installing a published Mainline release. Kernel development and historical Debian/UEFI work are documented separately.

> **Read first:** This is experimental firmware work. A mistake during partition flashing can erase data or leave the phone unable to boot. Keep a known-good recovery path and do not continue without backups.

## 1. Understand the boot flow

BareDroid uses the phone's Android A/B bootloader to load a Linux boot image. Linux then performs the rest of the startup:

```text
Android bootloader
        ↓
slot-B boot + vendor_boot
        ↓
Linux Mainline kernel 6.19.6
        ↓
BareDroid initramfs
        ↓
Ubuntu root filesystem on userdata
        ↓
systemd as PID 1
```

The phone's original system in slot A is intended to remain available as a recovery option. This is a safety convention, not a guarantee: every user must verify their own partition state before flashing.

## 2. Prepare the host and phone

Use a Linux host with:

```text
fastboot, adb, git, curl, Python 3, ssh, sha256sum and a reliable USB data cable
```

The phone must be a POCO F4 / Redmi K40S with codename `munch`, have an unlocked bootloader and have enough battery for several reboots. Enable no device-specific Android modifications unless the installation guide asks for them.

Put the phone in fastboot mode and run:

```bash
./scripts/01_check_device.sh
```

Do not proceed if the reported product is not `munch` or the bootloader is locked.

## 3. Back up before changing slot B

Back up the original boot images, DTBO images and radio-calibration partitions. The helper script can use ADB/recovery or `fastboot fetch` where the bootloader supports it:

```bash
./scripts/02_backup_partitions.sh
```

Stock Xiaomi fastboot often cannot read sensitive partitions. In that case, use a trusted recovery environment and verify that backups of `persist`, `modemst1`, `modemst2`, `fsg` and `fsc` were actually created. Keep the backup outside the repository.

## 4. Prepare the Ubuntu root filesystem

The published boot images do not include the complete root filesystem. Prepare an Ubuntu ARM64 minimal root filesystem and install it into the phone's userdata partition before or alongside the boot-image installation.

The initramfs expects an ext4 root filesystem with at least:

```text
/lib/systemd/systemd
/lib/modules/6.19.6-munch-ubuntu/
/lib/firmware/ath11k/QCA6390/hw2.0/
/etc/systemd/network/
/usr/sbin/sshd                 # recommended for first-boot access
```

Follow [Root filesystem preparation](docs/rootfs.md) for the required files, network setup and credential policy. Do not copy the example Wi-Fi configuration unchanged: it is a template only.

## 5. Verify and flash a release

Download the release files and place them in one directory. Verify them before flashing:

```bash
sha256sum -c SHA256SUMS.txt
```

From the repository root, place the matching `debian_mainline_boot_munch.img` and `debian_mainline_vendor_boot_munch.img` files next to the flashing script, then run:

```bash
./scripts/flash_mainline_munch_slot_b.sh
```

The script performs these destructive operations on slot B:

```bash
fastboot erase dtbo_b
fastboot flash boot_b debian_mainline_boot_munch.img
fastboot flash vendor_boot_b debian_mainline_vendor_boot_munch.img
fastboot --set-active=b
fastboot reboot
```

Erasing `dtbo_b` is part of the current `munch` workaround. It also means that a slot-B DTBO backup is required if you later want to restore the previous slot-B software.

## 6. First boot and USB recovery access

Connect the phone to the host with USB. The initramfs normally configures a USB Ethernet link using:

```text
Phone: 172.16.42.1/24
Host:  172.16.42.2/24
```

On the host, configure the USB network interface using NetworkManager or equivalent. Then connect with the credentials created during rootfs preparation:

```bash
ssh root@172.16.42.1
```

If SSH is not available yet, the current initramfs may expose a Telnet rescue shell on port 23. This is an emergency mechanism with no transport encryption; use it only over a directly connected trusted USB link.

Verify the boot before configuring Wi-Fi:

```bash
uname -a
cat /etc/os-release
ps -p 1 -o pid,comm,args
ip link
mount | grep -E ' / |sda34'
```

Expected results include Linux 6.19.6, Ubuntu ARM64 and `systemd` as PID 1.

## 7. Configure Wi-Fi without committing credentials

Create the target-side `wpa_supplicant` configuration locally, with your own SSID and password, and copy it to the phone. Enable the matching `wpa_supplicant@wlp1s0.service` and `systemd-networkd` configuration described in [Installation](docs/installation.md).

Never commit a real SSID, PSK, SSH private key or device-specific IP address to Git.

## 8. Return to Android or recover slot B

If slot A is intact, bootloader mode can select it:

```bash
fastboot --set-active=a
fastboot reboot
```

For a complete rollback procedure, including the DTBO dependency and backup requirements, see [Recovery](docs/recovery.md). Do not use the legacy rollback helper until you have replaced its hard-coded backup path with your own verified backup.

## 9. Continue with development

- [Architecture](docs/architecture.md) explains the DTB, initramfs and slot layout.
- [Building](docs/building.md) explains the current source-build prerequisites and known reproducibility gaps.
- [Troubleshooting](docs/troubleshooting.md) covers common boot, USB and Wi-Fi failures.
- [Hardware and limitations](docs/hardware.md) describes what is and is not currently supported.
