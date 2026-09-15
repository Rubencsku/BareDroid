# Security policy

BareDroid changes a phone's boot chain and exposes administrative services during early boot. Treat security reports about boot images, recovery access, credentials and update integrity seriously.

## Supported versions

Only the latest published release and the current default branch are candidates for security fixes. Older experimental images may remain available for research but should not be considered supported.

## Reporting a vulnerability

Do not open a public issue when a report includes a working exploit, private keys, credentials, partition data or a vulnerability that could compromise deployed devices. Contact the repository maintainer privately through the security-reporting method configured on the project hosting page.

Include:

- Affected release or commit.
- Device and bootloader state.
- Reproduction steps.
- Expected and observed behavior.
- Impact assessment.
- A minimal sanitized log when useful.

Do not attach complete partition images or radio-calibration backups.

## Current security limitations

The experimental initramfs starts an unauthenticated Telnet rescue shell on the USB gadget network. Anyone with access to that USB network can obtain a root shell during early boot. Use releases only in a physically trusted environment until rescue access becomes an explicit, disabled-by-default debug option.

Wi-Fi credentials were previously committed in configuration files. Removing them from the current tree does not remove them from Git history. Those credentials must be treated as compromised and rotated; do not reuse them in any deployment.

Other important limitations:

- Bootloader unlocking weakens the stock verified-boot trust model.
- Release integrity depends on users verifying published checksums.
- Rootfs credentials and SSH keys are supplied by the installer.
- Firmware and imported binaries require provenance review.
- There is not yet an authenticated over-the-air update system.

## Safe deployment baseline

- Use unique credentials and SSH keys.
- Disable root password login after bring-up.
- Remove or disable the Telnet rescue service for unattended deployment.
- Keep management services on trusted networks.
- Preserve verified recovery images offline.
- Monitor release checksums and rebuild provenance.
