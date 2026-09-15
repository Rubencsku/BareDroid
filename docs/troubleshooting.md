# Troubleshooting

Start by identifying the last successful stage: fastboot detection, bootloader image selection, kernel startup, initramfs, root mount, systemd, USB networking or Wi-Fi. Mixing symptoms from different stages usually leads to the wrong fix.

## Fastboot does not detect the phone

Check:

```bash
fastboot devices
lsusb
```

Try another data cable and USB port, confirm udev permissions and avoid charge-only cables. Do not begin a flash while the connection is intermittent.

## The product is not `munch`

Stop. BareDroid images in this repository are device-specific. Similar commercial names and similar Qualcomm SoCs do not make boot images interchangeable.

## ABL reports that no device tree was found

Likely causes:

- The DTB does not contain `qcom,board-id = <50 0>, <0 0>`.
- The DTS was compiled without `DTC_FLAGS_sm8250-xiaomi-munch := -@`.
- The wrong DTB was packaged into `vendor_boot`.
- An incompatible DTBO is still being applied.

Inspect the compiled DTB with `dtc`, compare its checksum with the release manifest and confirm that only `dtbo_b` was erased for the Mainline slot.

## The phone returns immediately to fastboot

Collect the bootloader message before retrying. Verify the Android boot image header version, partition names, image sizes and active slot. Do not repeatedly erase additional partitions.

Return to the verified slot A while diagnosing:

```bash
fastboot --set-active=a
fastboot reboot
```

## The kernel boots but userdata is not found

Use the initramfs rescue shell and inspect:

```sh
cat /proc/cmdline
ls -l /dev/sd* /dev/block/by-name 2>/dev/null
blkid
dmesg | grep -i -E 'ufs|scsi|sda|ext4'
```

The current command line and initramfs assume the reference layout at `/dev/sda34`. Confirm the partition by label, UUID and size before changing any filesystem.

## The ext4 mount fails

Look for the exact kernel message:

```sh
dmesg | grep -i ext4
blkid <root-device>
```

Common causes are an unformatted userdata partition, an unclean filesystem, a wrong device path or an unsupported filesystem feature. Repair the filesystem from a trusted recovery environment, not while it is mounted.

## `systemd` is missing or PID 1 fails

Mount the root filesystem in the rescue shell and check:

```sh
ls -l /sysroot/lib/systemd/systemd /sysroot/sbin/init
file /sysroot/lib/systemd/systemd
```

The binary must be ARM64 and executable. Also verify that `/dev`, `/proc` and `/sys` were moved into the new root and that the rootfs has the libraries required by systemd.

If `systemctl` loops or hangs after migrating from the legacy kernel, check for an obsolete `/usr/local/bin/systemctl` wrapper that shadows `/usr/bin/systemctl`.

## USB Ethernet does not appear

On the phone or rescue shell, inspect:

```sh
ls /sys/class/udc
ls /sys/kernel/config/usb_gadget
ip link
dmesg | grep -i -E 'dwc3|gadget|rndis|ecm'
```

On the host, inspect `dmesg`, `ip link` and NetworkManager. Interface names vary; do not assume a specific `enx...` name.

## SSH refuses the host key

A reinstalled phone can present a new SSH host key. Verify that the phone was intentionally reinstalled, then remove only the stale entry for the affected address:

```bash
ssh-keygen -R 172.16.42.1
```

Do not disable host-key checking globally.

## Wi-Fi interface is missing

Check PCIe enumeration, driver loading and firmware:

```bash
lspci -nn 2>/dev/null
lsmod | grep ath11k
modprobe ath11k_pci
dmesg | grep -i -E 'ath11k|qca6390|firmware|mhi|pci'
find /lib/firmware/ath11k/QCA6390/hw2.0 -maxdepth 1 -type f -ls
```

If modules report an invalid format, the rootfs module archive does not match the running kernel. If firmware is missing, verify the initramfs payload and redistribution source.

## Wi-Fi exists but does not associate

Check the regulatory country, SSID spelling, PSK, time and service logs:

```bash
systemctl status wpa_supplicant@wlp1s0.service
journalctl -u wpa_supplicant@wlp1s0.service -b
iw dev wlp1s0 link
networkctl status wlp1s0
```

Never paste an unredacted `wpa_supplicant.conf` into an issue.

## The display shows corrupted or static content

The project is currently optimized for headless use. Confirm that USB or Wi-Fi administration works before applying display power-management services. Display behavior may vary by panel revision and kernel changes.

## Docker fails to start

Verify the kernel and storage prerequisites:

```bash
docker info
mount | grep cgroup2
grep overlay /proc/filesystems
systemctl status docker
journalctl -u docker -b
```

Container support depends on the effective kernel configuration, not only on the kernel version string.

## Reporting a problem

Include:

- Exact device name, codename and storage variant.
- BareDroid release or Git commit.
- SHA-256 hashes of flashed images.
- Current slot and the last successful boot stage.
- Relevant logs as text.

Exclude passwords, Wi-Fi configuration, SSH keys, partition dumps, IMEI, serial numbers and radio calibration data.
