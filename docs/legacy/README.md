# Legacy development paths

BareDroid evolved through several approaches before the current Linux Mainline flow. The repository still contains scripts and notes from those experiments because they are useful engineering references, but they are not part of the supported installation path.

## Android kernel 4.19 path

Legacy files include:

```text
initramfs/init
scripts/build_boot_images.sh
scripts/flash_slot_b.sh
scripts/flash_mainline_slot_b.sh
configs/start_wifi.sh
configs/libprops_shim.so
```

That design used an Android-derived kernel and depended on Android vendor partitions, Qualcomm daemons, Bionic runtime components and a `wlan0` interface. It also launched services manually instead of switching to a modern systemd userspace in the same way as the current Mainline implementation.

Use these files only to understand prior bring-up work or to recover a known personal installation. They contain device-layout assumptions and may rely on ignored local artifacts.

## UEFI / EDK2 path

Legacy UEFI files include:

```text
scripts/03_flash_uefi_bootloader.sh
scripts/04_prepare_debian_installer.sh
```

The UEFI script can flash both boot slots and erase both DTBO partitions. That is materially different from the current slot-B Mainline workflow and should not be used as a beginner installation step.

## Debian server path

`scripts/05_server_post_install.sh` and older documentation were written for Debian. They configure Debian package repositories and services and should not be presented as Ubuntu 26.04 instructions without review.

## Archival policy

Legacy files should eventually move under a clearly named `legacy/` tree or historical branch. Until then:

- Current documentation must not link to them as installation steps.
- Their file headers should state that they are legacy.
- Destructive legacy scripts should require explicit confirmation and device validation.
- Secrets and workstation-specific paths must still be removed.
