# Recovery, backups and rollback

Recovery must be planned before flashing. BareDroid uses slot B for Linux and intends to preserve slot A, but this convention only helps if the original slot A is verified and the user has not overwritten it previously.

## Backup policy

Keep two copies of device-specific backups on different storage devices. At minimum, preserve:

```text
boot_a, boot_b
vendor_boot_a, vendor_boot_b
dtbo_a, dtbo_b
vbmeta_a, vbmeta_b
persist
modemst1, modemst2
fsg, fsc
devinfo
```

The radio and calibration partitions can contain unique device data. Never upload them to an issue, release or public repository.

After creating a backup, record checksums:

```bash
sha256sum backups/<timestamp>/*.img > backups/<timestamp>/SHA256SUMS.txt
```

Verify that files are not empty and have plausible partition sizes. A helper reporting success does not guarantee that a locked recovery environment allowed every read.

## Return to slot A

If slot A still contains a bootable system, enter fastboot mode and run:

```bash
fastboot getvar current-slot
fastboot --set-active=a
fastboot reboot
```

This changes the selected slot; it does not restore any partition contents. If slot A was modified, selecting it is not a recovery procedure.

## Restore the original slot-B boot chain

To restore slot B, use only backups from the same physical phone. Verify their checksums first, then flash the exact partitions that BareDroid changed:

```bash
BAREDROID_BACKUP_DIR=/path/to/verified-backup
fastboot flash boot_b "$BAREDROID_BACKUP_DIR/boot_b.img"
fastboot flash vendor_boot_b "$BAREDROID_BACKUP_DIR/vendor_boot_b.img"
fastboot flash dtbo_b "$BAREDROID_BACKUP_DIR/dtbo_b.img"
```

Select the desired slot only after all required writes succeed:

```bash
fastboot --set-active=b
fastboot reboot
```

Do not restore `persist`, modem or calibration partitions as a routine rollback step. Restore those only to the same device and only when there is evidence that they are damaged.

## Legacy rollback helper

`scripts/restore_419_slot_b.sh` references a developer-specific backup directory. It is retained as historical tooling and is unsafe to run unchanged on another checkout. A future replacement should:

- Require explicit image paths.
- Verify device product and bootloader state.
- Print and confirm the target serial number.
- Verify image checksums.
- Refuse missing or zero-length images.
- Avoid rebooting automatically when any step fails.

## Root filesystem recovery

The Linux root filesystem lives on userdata in the reference installation. Switching to slot A does not convert that ext4 filesystem back into Android userdata.

Before returning to stock Android permanently:

1. Copy any Linux data you need.
2. Restore the original boot-chain partitions as appropriate.
3. Use the stock recovery or documented factory procedure to recreate Android userdata.

Reformatting userdata erases the entire BareDroid root filesystem.

## Emergency initramfs shell

If the kernel boots but cannot mount userdata, the Mainline initramfs stays in an emergency shell loop and may expose Telnet on the USB gadget network. Useful checks include:

```sh
cat /proc/cmdline
ls -l /dev/sd* /dev/block/by-name 2>/dev/null
blkid
dmesg | tail -n 100
mount
```

Do not expose this network interface to an untrusted host. The current rescue shell is not authenticated.

## Information to collect before asking for help

Capture:

```bash
fastboot getvar product
fastboot getvar current-slot
fastboot getvar unlocked
fastboot getvar slot-count
```

Also provide the BareDroid release or commit, image checksums, the exact failing command and non-sensitive kernel logs. Remove serial numbers, MAC addresses, Wi-Fi credentials, private keys and partition images before posting publicly.
