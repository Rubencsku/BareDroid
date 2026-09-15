#!/bin/sh
mount -t configfs none /sys/kernel/config 2>/dev/null || true
if [ -d /sys/kernel/config/usb_gadget ]; then
    mkdir -p /sys/kernel/config/usb_gadget/g1
    cd /sys/kernel/config/usb_gadget/g1 || exit 0
    echo 0x1d6b > idVendor
    echo 0x0104 > idProduct
    mkdir -p strings/0x409
    echo 1140d081 > strings/0x409/serialnumber
    echo Xiaomi > strings/0x409/manufacturer
    echo "POCO F4 Linux Server" > strings/0x409/product
    mkdir -p configs/c.1/strings/0x409
    echo "ECM Network" > configs/c.1/strings/0x409/configuration
    echo 250 > configs/c.1/MaxPower
    mkdir -p functions/ecm.usb0 2>/dev/null || true
    ln -sf functions/ecm.usb0 configs/c.1/ 2>/dev/null || true
    UDC=$(ls /sys/class/udc 2>/dev/null | head -n 1)
    [ -n "$UDC" ] && echo "$UDC" > UDC 2>/dev/null || true
    sleep 1
    ip link set usb0 up 2>/dev/null || true
    ip addr add 172.16.42.1/24 dev usb0 2>/dev/null || true
fi
