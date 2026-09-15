#!/bin/bash
exec >> /var/log/wifi_boot.log 2>&1

PIDFILE=/run/start_wifi.pid
if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    echo "start_wifi is already running with PID $(cat $PIDFILE)"
    exit 0
fi
echo $$ > "$PIDFILE"

echo "=== Starting Wi-Fi setup at $(date) ==="

# 0. Basic network and hostname
hostname poco-server 2>/dev/null || true
ip link set lo up 2>/dev/null || true
ip addr add 127.0.0.1/8 dev lo 2>/dev/null || true

# 1. Character device nodes and cgroup2
rm -f /dev/null /dev/zero
mknod -m 666 /dev/null c 1 3
mknod -m 666 /dev/zero c 1 5

# Mount cgroup2 if not already mounted
if ! grep -q "cgroup2" /proc/mounts; then
    mkdir -p /sys/fs/cgroup
    mount -t cgroup2 none /sys/fs/cgroup 2>/dev/null || true
fi

# 2. Dynamic partitions (Android vendor & system)
if [ ! -e /dev/dm-0 ]; then
    dmsetup create vendor_a << "DMEOF" 2>/dev/null || true
0 1442176 linear /dev/sda29 6459280
1442176 8224 linear /dev/sda29 6449488
1450400 16 linear /dev/sda29 6459264
1450416 53120 linear /dev/sda29 7901456
1503536 32 linear /dev/sda29 3340480
1503568 576 linear /dev/sda29 3346192
DMEOF
fi

if [ ! -e /dev/dm-1 ]; then
    dmsetup create system_a << "DMEOF" 2>/dev/null || true
0 2056880 linear /dev/sda29 3351504
2056880 2256 linear /dev/sda29 3340512
2059136 16 linear /dev/sda29 3340448
2059152 8 linear /dev/sda29 3337152
DMEOF
fi

mknod /dev/dm-0 b 253 0 2>/dev/null || true
mknod /dev/dm-1 b 253 1 2>/dev/null || true
mkdir -p /dev/mapper
ln -sf /dev/dm-0 /dev/mapper/vendor_a
ln -sf /dev/dm-1 /dev/mapper/system_a

mkdir -p /mnt/android_system /mnt/android_vendor /mnt/vendor/persist /apex/com.android.runtime
mount -t erofs -o ro /dev/dm-0 /mnt/android_vendor 2>/dev/null || mount -t ext4 -o ro /dev/dm-0 /mnt/android_vendor 2>/dev/null || true
mount -t erofs -o ro /dev/dm-1 /mnt/android_system 2>/dev/null || mount -t ext4 -o ro /dev/dm-1 /mnt/android_system 2>/dev/null || true
mount /dev/sda22 /mnt/vendor/persist 2>/dev/null || true

# Mount apex runtime linker
if [ ! -f /apex/com.android.runtime/bin/linker64 ]; then
    if [ -f /opt/apex_payload.img ]; then
        mount -o loop,ro /opt/apex_payload.img /apex/com.android.runtime 2>/dev/null || true
    fi
fi

# 3. Partition by-name symlinks
mkdir -p /dev/block/bootdevice/by-name
for dev in /dev/sd[a-z][0-9]*; do
    label=$(blkid -s PARTLABEL -o value "$dev" 2>/dev/null || true)
    if [ -n "$label" ]; then
        ln -sf "$dev" "/dev/block/bootdevice/by-name/$label"
    fi
done

# 4. Firmware and MAC address
mkdir -p /lib/firmware/wlan/qca_cld /mnt/vendor/persist/wlan /data/vendor/mac_addr
cat << "MACEOF" > /lib/firmware/wlan/qca_cld/wlan_mac.bin
Intf0MacAddress=34C9F01140D0
Intf1MacAddress=34C9F01140D1
Intf2MacAddress=34C9F01140D2
Intf3MacAddress=34C9F01140D3
END
MACEOF
cp -f /lib/firmware/wlan/qca_cld/wlan_mac.bin /mnt/vendor/persist/wlan_mac.bin 2>/dev/null || true
cp -f /lib/firmware/wlan/qca_cld/wlan_mac.bin /mnt/vendor/persist/wlan/wlan_mac.bin 2>/dev/null || true
chmod 644 /lib/firmware/wlan/qca_cld/wlan_mac.bin

# 5. Daemons
if ! pgrep qrtr-ns >/dev/null 2>&1; then
    qrtr-ns &
    sleep 1
fi

export LD_PRELOAD=/usr/local/lib/libprops_shim.so
export LD_LIBRARY_PATH=/mnt/android_vendor/lib64:/mnt/android_system/system/lib64:/apex/com.android.runtime/lib64:/apex/com.android.runtime/lib64/bionic

if ! pgrep -f rmt_storage >/dev/null 2>&1; then
    nohup /apex/com.android.runtime/bin/linker64 /mnt/android_vendor/bin/rmt_storage </dev/null >/var/log/rmt_storage.log 2>&1 &
    sleep 1
fi

if ! pgrep -f cnss-daemon >/dev/null 2>&1; then
    nohup /apex/com.android.runtime/bin/linker64 /mnt/android_vendor/bin/cnss-daemon -n -d </dev/null >/var/log/cnss-daemon.log 2>&1 &
    sleep 2
fi

# 6. Driver trigger
if [ -e /sys/devices/platform/soc/b0000000.qcom,cnss-qca6390/fs_ready ]; then
    echo 1 > /sys/devices/platform/soc/b0000000.qcom,cnss-qca6390/fs_ready
fi

python3 -c "with open(\"/dev/wlan\", \"wb\") as f: f.write(b\"ON\x00\")" 2>/dev/null || true

# 7. Association and DHCP
for attempt in $(seq 1 30); do
    if ip link show wlan0 >/dev/null 2>&1; then
        echo "wlan0 detected! Bringing interface up..."
        ip link set wlan0 up 2>/dev/null || true
        if ! pgrep -f wpa_supplicant >/dev/null 2>&1; then
            mkdir -p /run/wpa_supplicant
            nohup wpa_supplicant -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf > /var/log/wpa_supplicant.log 2>&1 &
            sleep 4
        fi
        dhclient -v wlan0 || true
        WIFI_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP "(?<=inet\s)\d+(\.\d+){3}")
        if [ -n "$WIFI_IP" ]; then
            echo "SUCCESS: Wi-Fi connected! IP: $WIFI_IP"
            echo "$WIFI_IP" > /root/wifi_ip.txt
            echo "POCO F4 Ubuntu 26.04 LTS Minimal Server - Wi-Fi IP: $WIFI_IP" > /etc/issue
            chronyd -q "pool pool.ntp.org iburst" 2>/dev/null || true
            if [ -x /usr/local/bin/start_desktop.sh ]; then
                nohup /usr/local/bin/start_desktop.sh > /var/log/desktop_boot.log 2>&1 &
            fi
            if [ -x /usr/local/bin/hermes-service ]; then
                /usr/local/bin/hermes-service start > /var/log/hermes_boot.log 2>&1 &
            fi
            break
        fi
    fi
    sleep 2
done

# Keep-alive loop
while true; do
    sleep 30
    if ! ip -4 addr show wlan0 2>/dev/null | grep -q "inet "; then
        echo "Wi-Fi disconnected, reconnecting..."
        ip link set wlan0 up 2>/dev/null || true
        dhclient -v wlan0 2>/dev/null || true
    fi
done
