#!/usr/bin/env bash
# ==============================================================================
# setup_touch.sh - Re-bind FocalTech FT3658 Touchscreen on POCO F4 (munch)
# ==============================================================================

echo "[*] Checking touchscreen status..."
if [ -e /dev/input/event0 ] && grep -q "fts_ts" /proc/bus/input/devices 2>/dev/null; then
    echo "[+] Touchscreen driver already active and registered."
    exit 0
fi

# If display is active, trigger touch IC rebind on spi1.0
if [ -d /sys/bus/spi/drivers/fts_ts ]; then
    echo "[*] Attempting to bind fts_ts driver to spi1.0..."
    echo "spi1.0" > /sys/bus/spi/drivers/fts_ts/unbind 2>/dev/null || true
    sleep 0.2
    echo "spi1.0" > /sys/bus/spi/drivers/fts_ts/bind 2>/dev/null || true
    sleep 0.5
fi

if grep -q "fts_ts" /proc/bus/input/devices 2>/dev/null; then
    echo "[+] Touchscreen successfully registered!"
else
    echo "[-] Touchscreen not yet responding (waiting for display power rails)."
fi
