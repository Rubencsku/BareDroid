# Licensing and redistribution notes

BareDroid is being prepared for open-source collaboration, but the current repository does not yet have one license that can automatically be applied to every file.

## Source written for BareDroid

Project-owned scripts and documentation need an explicit project license chosen by the maintainer. Until a root `LICENSE` file is added, contributors and downstream users should not assume permission terms beyond those stated in individual files.

Choosing the project license is a maintainer decision. It should be completed before accepting substantial third-party contributions or advertising the entire repository as licensed open source.

## Linux device tree

`dts/sm8250-xiaomi-munch.dts` carries this SPDX expression:

```text
GPL-2.0-only OR BSD-2-Clause
```

Keep its copyright and SPDX notices when modifying or redistributing it. Contributions derived from other kernel device trees must preserve the relevant authorship and license information.

## Imported Android utilities

Files such as `mkbootimg.py`, `unpack_bootimg.py` and `avbtool.py` originate from Android tooling and retain their upstream license notices. Do not replace or remove those notices. Release documentation should identify the upstream revision used.

## Firmware

The files under `firmware/` are binary firmware, not open-source driver code. A driver being open source does not make the firmware blob open source.

Before publishing or mirroring firmware in a release:

1. Identify the original source package or device image.
2. Record exact checksums.
3. Confirm that redistribution is permitted.
4. Preserve required notices.
5. Prefer documented extraction by the device owner if redistribution rights are unclear.

The same review applies to firmware copied from Android `vendor`, `persist`, modem or DSP partitions.

## Prebuilt binaries

The repository contains or references prebuilt tools and libraries. Each binary needs provenance, source availability where required and a license record. A future `THIRD_PARTY_NOTICES.md` should list, at minimum:

- Component name and version.
- Upstream project and source URL.
- License.
- Local file paths.
- Modifications.
- Rebuild instructions or reason for distributing a binary.

## Releases

Every release should distinguish:

- Project source covered by the selected BareDroid license.
- Linux kernel output and corresponding source obligations.
- Android tooling with upstream licenses.
- Redistributable firmware.
- Files that users must extract from their own device.

This document is a repository audit note, not legal advice. The maintainer should complete the license and firmware-provenance review before the next public release.
