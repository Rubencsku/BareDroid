# Install a BareDroid release

This guide describes the current release-based installation path for the Xiaomi POCO F4 / Redmi K40S (`munch`). It does not apply to other devices.

## Important warnings

- The bootloader must already be unlocked.
- Unlocking the bootloader and preparing userdata can erase all user data.
- Never flash an image unless its device and slot are clearly identified.
- Keep the original Android slot and verified partition backups available.
- Do not use the example Wi-Fi configuration with real credentials committed to Git.

## Requirements

### Phone

- Xiaomi POCO F4 or Redmi K40S with codename `munch`.
- Unlocked bootloader.
- Reliable USB-C data cable.
- Enough battery for several reboots.

### Linux host

Install or make available:

```text
adb, fastboot, curl, openssh-client, Python 3 and sha256sum
```

The repository can use a local `platform-tools/` directory when one is present; otherwise it uses the commands from `PATH`.

## 1. Clone the repository and check the device

```bash
git clone https://github.com/Rubencsku/BareDroid.git
cd BareDroid
git checkout v1.0.0-munch
```

Boot the phone into fastboot mode, connect it and run:

```bash
./scripts/01_check_device.sh
```

The expected product is `munch` or `munch_in`, and the bootloader must report `yes` for `unlocked`.

If the script reports another product, stop. Do not attempt to adapt a `munch` image by changing only the filename.

## 2. Back up critical partitions

Run the helper and inspect the resulting files:

```bash
./scripts/02_backup_partitions.sh
find backups -maxdepth 2 -type f -printf '%p %s bytes\n'
```

The most important items are the radio-calibration partitions (`persist`, `modemst1`, `modemst2`, `fsg` and `fsc`) and the original boot/DTBO images. Xiaomi fastboot may refuse raw reads; use a trusted recovery environment when necessary.

Do not store these backups in a public repository. They may contain device-specific identifiers, calibration data or other sensitive information.

## 3. Prepare the root filesystem

Release boot images do not contain Ubuntu itself. Prepare the target root filesystem before flashing or use a documented recovery environment to provision it afterward. See [Root filesystem preparation](rootfs.md).

At minimum, the ext4 root filesystem must contain:

```text
/lib/systemd/systemd
/lib/modules/6.19.6-munch-ubuntu/
/lib/firmware/ath11k/QCA6390/hw2.0/
/etc/systemd/network/
```

Create a root account or administrative user with credentials chosen by you. SSH keys are strongly recommended. The repository does not provide a safe universal default password.

## 4. Verify release artifacts

Download the files from the [project release page](https://github.com/Rubencsku/BareDroid/releases). Keep the image files and `SHA256SUMS.txt` in the same directory, then run:

```bash
sha256sum -c SHA256SUMS.txt
```

At minimum, the matching release must provide:

```text
debian_mainline_boot_munch.img
debian_mainline_vendor_boot_munch.img
```

The flashing helper expects both images in the repository root. Copy the verified files there before continuing:

```bash
BAREDROID_RELEASE_DIR=/path/to/verified-release
cp "$BAREDROID_RELEASE_DIR/debian_mainline_boot_munch.img" .
cp "$BAREDROID_RELEASE_DIR/debian_mainline_vendor_boot_munch.img" .
```

## 5. Flash slot B

The repository provides a helper for the current Mainline images:

```bash
./scripts/flash_mainline_munch_slot_b.sh
```

The helper waits for fastboot and performs:

```bash
fastboot erase dtbo_b
fastboot flash boot_b debian_mainline_boot_munch.img
fastboot flash vendor_boot_b debian_mainline_vendor_boot_munch.img
fastboot --set-active=b
fastboot reboot
```

`fastboot erase dtbo_b` is a device-specific workaround. It prevents the Android DTBO overlay from being applied to the Mainline device tree. It is destructive, so keep a verified `dtbo_b` backup if slot-B rollback matters to you.

## 6. Configure the USB recovery network

The Mainline initramfs normally creates a USB Ethernet gadget with this addressing:

```text
Phone: 172.16.42.1/24
Host:  172.16.42.2/24
```

On the host, identify the new USB network interface and assign the host address using NetworkManager or equivalent. For a temporary configuration:

```bash
BAREDROID_USB_IF=replace-with-interface-name
sudo ip addr add 172.16.42.2/24 dev "$BAREDROID_USB_IF"
sudo ip link set "$BAREDROID_USB_IF" up
```

Then connect using the credentials created during rootfs preparation:

```bash
ssh root@172.16.42.1
```

The current initramfs may also expose a Telnet rescue shell on port 23. Telnet is unencrypted and should only be used over a directly connected trusted USB link.

## 7. Verify the first boot

Run:

```bash
uname -r
cat /etc/os-release
ps -p 1 -o pid,comm,args
ip link
findmnt /
```

Expected results:

- Kernel release contains `6.19.6-munch-ubuntu`.
- The system identifies as Ubuntu ARM64.
- PID 1 is `/lib/systemd/systemd` or an equivalent systemd path.
- The root filesystem is mounted from the userdata block device.

## 8. Configure Wi-Fi

Copy [the Wi-Fi template](../setup_files/wpa_supplicant.conf) to the target, add your regulatory country and your own network block. Then create `/etc/systemd/network/20-wireless.network`:

```ini
[Match]
Name=wlp1s0

[Network]
DHCP=yes
RouteMetric=100
```

Enable networking:

```bash
systemctl enable --now systemd-networkd
systemctl enable --now wpa_supplicant@wlp1s0.service
```

Confirm the driver and address:

```bash
ip link show wlp1s0
iw dev
ip address show wlp1s0
```

## 9. Optional headless configuration

Display power management is still device-specific. Apply it only after USB or Wi-Fi administration works, and keep a recovery connection available. See [Hardware and limitations](hardware.md).

## 10. Recovery

To boot the untouched Android slot, enter fastboot mode and run:

```bash
fastboot --set-active=a
fastboot reboot
```

For slot-B rollback and DTBO restoration, follow [Recovery](recovery.md). The legacy `restore_419_slot_b.sh` script contains a machine-specific backup path and should not be used unchanged.
