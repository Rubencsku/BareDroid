# Contributing to BareDroid

BareDroid welcomes focused, reproducible contributions for running native Linux on Android hardware. English is the documentation language for the project.

## Before opening a change

- Search existing issues and documentation.
- Identify whether the change targets the current Mainline flow or legacy development.
- Do not mix unrelated formatting, kernel, firmware and documentation changes.
- Keep device-specific behavior behind clearly named files and metadata.

## Development expectations

Changes that affect boot or hardware should include:

- Exact device codename and variant.
- Kernel version and configuration changes.
- Build commands and toolchain identity.
- Test results and relevant logs.
- A recovery plan.
- Documentation updates.

Changes to shell scripts should pass `bash -n` or `sh -n` as appropriate. Python changes should at least compile cleanly and should include targeted tests when practical.

## Documentation style

- Write documentation and code-facing user messages in English.
- Use relative repository links.
- Separate confirmed behavior from assumptions and planned work.
- Avoid personal IP addresses, usernames, passwords and workstation paths.
- State destructive effects immediately before destructive commands.
- Keep the README concise and put detailed procedures in `docs/`.

## Security and privacy

Never commit:

- Wi-Fi SSIDs or passwords.
- SSH private keys or reusable passwords.
- Full partition backups.
- IMEI, serial numbers or radio calibration data.
- Private logs containing tokens or network credentials.

Follow `SECURITY.md` for vulnerability reports.

## Device support proposals

A new device port should not modify `munch` constants in place. Add a device-specific directory or metadata definition that covers:

- Compatible strings and bootloader board identifiers.
- Partition layout and root identifier.
- Kernel configuration and DTS patches.
- Boot image format.
- Firmware requirements and provenance.
- Hardware support matrix.
- Backup and rollback procedure.

## Commit scope

Prefer small commits with a clear purpose, for example:

```text
docs: document rootfs provisioning requirements
fix(munch): validate product before flashing slot B
build: assemble mainline initramfs reproducibly
```

Do not include generated images or personal backups in commits. Publish generated artifacts through a release with checksums and a build manifest.
