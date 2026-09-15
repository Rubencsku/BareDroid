# Hardware support and operating guidance

This page describes the current POCO F4 (`munch`) reference target. It separates demonstrated server functionality from hardware that still needs repeatable validation.

## Support matrix

| Component | Status | Notes |
| --- | --- | --- |
| CPU / SMP | Working in the reference build | Snapdragon 870 / SM8250 |
| UFS storage | Working | Reference rootfs is on userdata, observed as `/dev/sda34` |
| Native systemd | Working | `systemd` runs as PID 1 |
| USB gadget network | Working in the reference build | RNDIS or ECM, normally `172.16.42.1/24` |
| Wi-Fi | Working in the reference build | QCA6390 with `ath11k_pci`, normally `wlp1s0` |
| Container workloads | Demonstrated | Requires cgroups v2, namespaces and overlayfs |
| Display | Experimental | Project defaults to a headless server profile |
| Touch input | Experimental | Configuration helpers exist; not part of the release installation contract |
| Bluetooth | Not documented as supported | Needs repeatable validation and firmware documentation |
| Audio | Not documented as supported | Not required for the server profile |
| Cameras | Not documented as supported | Not required for the server profile |
| Cellular modem | Not supported as a documented service | Preserve modem and calibration partitions |
| Suspend / resume | Not documented as supported | Avoid relying on suspend for server operation |
| Charging control | Device-specific | Monitor temperature and battery behavior |

“Working” means demonstrated on the reference installation, not yet continuously tested across all regional and storage variants.

## Variant information to record

Hardware reports should include:

- Marketing model and codename.
- RAM and storage capacity.
- Regional variant.
- Bootloader version and Android firmware base.
- Display panel identifier when relevant.
- Output of `uname -a`, `cat /proc/device-tree/model` and `lspci -nn`.

## Continuous operation

Smartphones were not designed as unattended rack servers. For long-running use:

- Keep the phone away from heat and direct sunlight.
- Remove insulating cases when safe.
- Use a stable, appropriately rated power supply and cable.
- Monitor battery temperature and state of charge.
- Avoid leaving a lithium battery hot and continuously at maximum charge.
- Keep the screen off after confirming remote administration works.
- Maintain external backups; internal UFS is not redundant storage.

Do not assume the battery provides a guaranteed number of backup hours. Runtime depends on battery health, radio use, workload, temperature and attached USB devices.

## Temperature monitoring

Thermal-zone names and units vary. Inspect them before building alerts:

```bash
for zone in /sys/class/thermal/thermal_zone*; do
  printf '%s ' "$zone"
  cat "$zone/type" 2>/dev/null
  cat "$zone/temp" 2>/dev/null
done
```

Most Linux thermal values are reported in millidegrees Celsius, but software should verify the sensor and scaling instead of assuming it.

## USB hubs and Ethernet

USB-C hubs, Ethernet adapters and power-delivery combinations vary considerably. Test the exact hub under load before depending on it. Verify:

- The adapter chipset has a Mainline Linux driver.
- Charging and USB host mode can coexist on the phone and kernel build.
- The power supply covers the phone and attached storage.
- External storage survives disconnect and reboot tests.

Avoid claiming universal Gigabit or power-delivery compatibility without a tested-device list.

## AMOLED protection

Static boot consoles can damage an AMOLED panel over time. The repository includes experimental display and power-management helpers, but panel paths and DRM behavior can change between kernel versions.

Before enabling an automatic screen-off service:

1. Confirm SSH access over USB and Wi-Fi.
2. Record the actual `/sys/class/backlight` and DRM connector paths.
3. Test recovery after a failed service start.
4. Verify that the power button does not trigger an unwanted shutdown.

Do not describe a software blanking command as a guarantee of zero panel power unless it has been measured on the target hardware.

## Server workload guidance

The reference system has demonstrated Docker workloads, but production reliability still depends on:

- Thermal limits under sustained CPU and storage activity.
- Battery health and charging behavior.
- Database write endurance and backup policy.
- Network recovery after access-point or power failures.
- A tested update and rollback process.

Treat the phone as an experimental edge server until monitoring and recovery have been validated for the intended workload.
