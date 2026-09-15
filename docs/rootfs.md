# Root filesystem preparation

BareDroid boot images contain the kernel and early userspace, not a complete Linux distribution. The phone therefore needs an ARM64 root filesystem on its userdata partition before the Mainline boot can reach `systemd`.

## Current expectation

The Mainline initramfs searches for the root filesystem in this order:

1. `/dev/sda34`
2. `/dev/block/sda34`
3. `/dev/block/by-name/userdata`
4. The development UUID currently embedded in `initramfs/init_mainline_munch`

The block-device number and embedded UUID are implementation details from the reference phone. Before supporting another storage layout, replace this logic with a stable partition identifier and test the recovery path.

The filesystem must be ext4 and must contain a bootable ARM64 userspace. The initramfs eventually runs:

```sh
exec switch_root /sysroot /lib/systemd/systemd
```

## Obtain an Ubuntu ARM64 userspace

Download an official Ubuntu Base ARM64 archive for the release used by the matching BareDroid release. Verify the checksum published by Ubuntu before extracting it.

Create a working directory on a Linux host:

```bash
BAREDROID_UBUNTU_ARCHIVE=/path/to/ubuntu-base-arm64.tar.gz
mkdir -p rootfs-work/rootfs
sudo tar -xpf "$BAREDROID_UBUNTU_ARCHIVE" \
  -C rootfs-work/rootfs
```

Use `sudo` so ownership, device nodes and permissions are preserved. Do not build a root filesystem as an unprivileged archive and then assume that ownership will be repaired automatically.

## Configure the base system

The root filesystem should include:

- `systemd` and `systemd-sysv`
- OpenSSH server
- `sudo`, `iproute2`, `kmod`, `iw` and `wpasupplicant`
- CA certificates and package-management tools
- A configured hostname and `/etc/hosts`
- An administrative account and SSH authorized keys

When preparing the ARM64 filesystem on an x86-64 host, use an ARM64 chroot through `qemu-user-static`, a native ARM64 machine, or another reproducible image-building system. A typical package set is:

```text
systemd systemd-sysv openssh-server sudo iproute2 kmod iw
wpasupplicant ca-certificates curl locales tzdata
```

The repository does not currently provide a complete automated rootfs builder. Record the exact Ubuntu archive, package versions and configuration used for a release so another contributor can reproduce it.

## User and SSH policy

Do not publish a universal root password. During image preparation:

1. Create an administrative user.
2. Install the user's SSH public key.
3. Disable empty passwords.
4. Prefer disabling SSH password authentication after first boot.
5. Keep private keys outside the rootfs build directory and outside Git.

If root SSH is enabled temporarily for bring-up, remove it once a sudo-capable user works.

## Network configuration

The initramfs writes a basic networkd file for interfaces named `usb*` or `rndis*` and assigns `172.16.42.1/24`. Ensure `systemd-networkd` is enabled in the root filesystem.

For Wi-Fi, copy `setup_files/25-wireless.network` and create a local `wpa_supplicant` configuration from the repository template. Add the correct ISO 3166-1 alpha-2 regulatory country and add credentials only on the target or in a private build secret.

Do not commit the generated Wi-Fi file.

## Kernel modules and firmware

The release initramfs can deploy two embedded payloads on first boot:

```text
/opt/modules.tar.gz
/opt/ath11k_firmware.tar.gz
```

They are extracted into the mounted root filesystem when the expected files are missing. After first boot, verify:

```bash
find /lib/modules/$(uname -r) -maxdepth 2 -type f | head
ls -l /lib/firmware/ath11k/QCA6390/hw2.0/
depmod -a
```

The module archive and kernel image must come from the same build. Mixing releases can produce `invalid module format` errors.

## Install the filesystem on userdata

Provisioning userdata is destructive. The exact command depends on the recovery environment and on how the phone exposes its storage. A safe workflow is:

1. Boot a trusted recovery environment without flashing it when possible.
2. Verify the userdata block device by partition name, size and filesystem metadata.
3. Back up any remaining data.
4. Create an ext4 filesystem only on the confirmed userdata target.
5. Mount it and extract the prepared rootfs while preserving ownership and extended attributes.
6. Unmount it cleanly and run an ext4 filesystem check.

Do not copy `/dev/sda34` from the reference device into a destructive host command. Device numbering can change between recovery and kernel environments.

The repository still needs an automated and independently tested provisioning tool. Until that exists, release notes should state the exact recovery and commands used for the tested image.

## Pre-boot checklist

Before selecting slot B, inspect the mounted root filesystem:

```bash
BAREDROID_ROOT_MOUNT=/mnt/baredroid-root
test -x "$BAREDROID_ROOT_MOUNT/lib/systemd/systemd"
test -d "$BAREDROID_ROOT_MOUNT/etc/systemd/system"
test -f "$BAREDROID_ROOT_MOUNT/etc/os-release"
ls -ld "$BAREDROID_ROOT_MOUNT/root" "$BAREDROID_ROOT_MOUNT/home"
```

Also verify that the SSH keys and account configuration belong to the intended user and that no private build secrets remain in shell history or temporary files.
