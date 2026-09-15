#!/bin/bash
# ==============================================================================
# POCO F4 (munch) - Physical AMOLED GNOME Mobile Desktop & Remote Access
# Phoc (wlroots DRM) + Phosh (GNOME Mobile Shell) + poco-dashboard
# WayVNC (5900), HTTPS noVNC (6080), AMOLED 60s Sleep & Power Button Wakeup
# ==============================================================================

echo "=== Starting POCO F4 GNOME Mobile Display & Desktop at $(date) ==="

# 1. Ensure loopback is up
ip link set lo up 2>/dev/null || true
ip addr add 127.0.0.1/8 dev lo 2>/dev/null || true

# 2. Ensure hostname and hosts entries
if [ "$(hostname)" != "poco-server" ]; then
    hostname poco-server 2>/dev/null || true
fi
if ! grep -q "poco-server" /etc/hosts; then
    echo "127.0.0.1 localhost poco-server" >> /etc/hosts
fi

# 3. Ensure D-Bus system bus is running
if ! pgrep -x dbus-daemon >/dev/null 2>&1; then
    echo "[*] Starting D-Bus system message bus..."
    /etc/init.d/dbus start 2>/dev/null || systemctl start dbus 2>/dev/null || true
fi

# 4. Ensure groups and permissions for user poco
groupadd -f video 2>/dev/null || true
groupadd -f render 2>/dev/null || true
groupadd -f input 2>/dev/null || true
usermod -aG video,render,input poco 2>/dev/null || true

# 5. Ensure POSIX shared memory tmpfs (/dev/shm)
mkdir -p /dev/shm 2>/dev/null || true
if ! mount | grep -q "/dev/shm"; then
    mount -t tmpfs -o rw,nosuid,nodev,noexec,relatime,size=1024M tmpfs /dev/shm 2>/dev/null || true
fi
chmod 1777 /dev/shm 2>/dev/null || true

# 6. Ensure devpts permissions for terminal PTYs
mount -o remount,gid=5,mode=620,ptmxmode=666 /dev/pts 2>/dev/null || true
chmod 666 /dev/ptmx 2>/dev/null || true

# 7. Ensure permissions for device nodes
chmod 666 /dev/dri/card0 /dev/dri/renderD128 2>/dev/null || true
chmod 666 /dev/input/event* 2>/dev/null || true
chmod 666 /dev/random /dev/urandom /dev/null /dev/zero /dev/full 2>/dev/null || true
chmod 666 /sys/class/backlight/*/brightness 2>/dev/null || true

# 8. Ensure Display Panel & Touch Power Rails are enabled (GPIO 1171 and GPIO 1169 if present)
echo soc:display_gpio_regulator_vci > /sys/bus/platform/drivers/reg-fixed-voltage/unbind 2>/dev/null || true
echo soc:touch_vddio_vreg > /sys/bus/platform/drivers/reg-fixed-voltage/unbind 2>/dev/null || true
echo soc:oled-dvdd-gpio-regulator > /sys/bus/platform/drivers/reg-fixed-voltage/unbind 2>/dev/null || true
if [ ! -d /sys/class/gpio/gpio1171 ] && [ -d /sys/class/gpio ]; then
    echo 1171 > /sys/class/gpio/export 2>/dev/null || true
fi
if [ ! -d /sys/class/gpio/gpio1169 ] && [ -d /sys/class/gpio ]; then
    echo 1169 > /sys/class/gpio/export 2>/dev/null || true
fi
[ -d /sys/class/gpio/gpio1171 ] && echo out > /sys/class/gpio/gpio1171/direction 2>/dev/null && echo 1 > /sys/class/gpio/gpio1171/value 2>/dev/null || true
[ -d /sys/class/gpio/gpio1169 ] && echo out > /sys/class/gpio/gpio1169/direction 2>/dev/null && echo 1 > /sys/class/gpio/gpio1169/value 2>/dev/null || true

# 9. Disconnect Qualcomm Virtual writeback connector to avoid swapchain test loops
echo "off" > /sys/class/drm/card0-Virtual-1/status 2>/dev/null || true
echo "off" > /sys/class/drm/card0-Writeback-1/status 2>/dev/null || true

# 10. Ensure TLS certificates for HTTPS noVNC exist
if [ ! -f /etc/weston/tls.key ] || [ ! -f /etc/weston/tls.crt ]; then
    echo "[*] Generating self-signed TLS certificates for HTTPS noVNC..."
    mkdir -p /etc/weston
    openssl req -x509 -newkey rsa:2048 -keyout /etc/weston/tls.key -out /etc/weston/tls.crt -days 365 -nodes -subj '/CN=poco-server' 2>/dev/null || true
    chmod 644 /etc/weston/tls.crt /etc/weston/tls.key
fi

# 11. Ensure seatd service is running without VT binding
if ! pgrep -x seatd >/dev/null 2>&1; then
    echo "[*] Starting seatd..."
    rm -f /run/seatd.sock 2>/dev/null || true
    SEATD_VTBOUND=0 nohup seatd -g video -u root </dev/null >/var/log/seatd.log 2>&1 &
    sleep 0.5
fi
chmod 666 /run/seatd.sock 2>/dev/null || true

# 12. Ensure XDG_RUNTIME_DIR for user poco (UID 1000)
RUNTIME_DIR="/run/user/1000"
mkdir -p "$RUNTIME_DIR"
chown -R poco:poco "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

# 13. Ensure Phoc mobile configuration exists
mkdir -p /etc/phosh
cat << 'EOF_PHOC' > /etc/phosh/phoc.ini
[core]
xwayland = true

[output:DSI-1]
enable = true
scale = 2
mode = 1080x2400
EOF_PHOC

# 14. Turn off any legacy Weston instance
pkill -9 weston 2>/dev/null || true

# 15. Start Phoc Compositor + Phosh (GNOME Mobile Shell)
if ! pgrep -x phoc >/dev/null 2>&1; then
    echo "[*] Starting Phoc (wlroots DRM) & Phosh GNOME Mobile on AMOLED (1080x2400)..."
    rm -f "$RUNTIME_DIR"/wayland-* 2>/dev/null || true
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
    rm -f /home/poco/.local/state/phoc/outputs.gvdb 2>/dev/null || true
    touch /var/log/phoc.log
    chown poco:poco /var/log/phoc.log
    
    # Set backlight brightness to active level
    for b in /sys/class/backlight/*/brightness; do
        [ -f "$b" ] && echo 600 > "$b" 2>/dev/null || true
    done
    
    su - poco -c "WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 LD_PRELOAD=/usr/local/lib/libdrm_dedup.so LIBSEAT_BACKEND=seatd XDG_RUNTIME_DIR=$RUNTIME_DIR nohup dbus-run-session -- phoc -C /etc/phosh/phoc.ini -E \"/usr/libexec/phosh -U\" </dev/null >/var/log/phoc.log 2>&1 &"
fi

# 16. Wait for Wayland display socket
for i in $(seq 1 15); do
    if [ -S "$RUNTIME_DIR/wayland-0" ] || [ -S "$RUNTIME_DIR/wayland-1" ]; then
        echo "[+] Wayland compositor ready."
        # Ensure DSI-1 physical display output is enabled and scaled
        sleep 0.5
        su - poco -c "WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=$RUNTIME_DIR wlr-randr --output DSI-1 --on --scale 2 2>/dev/null" || true
        break
    fi
    sleep 0.5
done

# 17. Start WayVNC on port 5900 with auto-restart supervisor
if ! pgrep -f "wayvnc 0.0.0.0 5900" >/dev/null 2>&1; then
    echo "[*] Starting WayVNC server on port 5900 (with auto-restart)..."
    rm -f /run/user/1000/wayvncctl 2>/dev/null || true
    su - poco -c "bash -c 'while true; do LD_PRELOAD=/usr/local/lib/libwayvnc_shim.so WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=$RUNTIME_DIR wayvnc 0.0.0.0 5900; sleep 1; done' </dev/null >/var/log/wayvnc.log 2>&1 &"
fi

# 18. Start Websockify / noVNC with SSL support (HTTPS on port 6080 -> VNC 5900)
if ! pgrep -f "websockify.*6080" >/dev/null 2>&1 && [ -d /usr/share/novnc ]; then
    echo "[*] Starting Websockify HTTPS noVNC on port 6080..."
    python3 /usr/bin/websockify --web /usr/share/novnc --cert /etc/weston/tls.crt --key /etc/weston/tls.key -D 6080 localhost:5900
fi

# 19. Start Squeekboard on-screen keyboard
if ! pgrep -x squeekboard >/dev/null 2>&1; then
    echo "[*] Starting Squeekboard virtual keyboard..."
    DBUS_ADDR=$(cat /proc/$(pgrep -u poco phosh | head -n1)/environ 2>/dev/null | tr "\0" "\n" | grep DBUS | cut -d= -f2-)
    su - poco -c "DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=$RUNTIME_DIR nohup /usr/bin/squeekboard </dev/null >/tmp/squeekboard.log 2>&1 &"
fi

# 20. Ensure GNOME / Phosh lockscreen is completely disabled
DBUS_ADDR=$(cat /proc/$(pgrep -u poco phosh | head -n1)/environ 2>/dev/null | tr "\0" "\n" | grep DBUS | cut -d= -f2-)
su - poco -c "DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR bash -c '
    gsettings set sm.puri.phosh.lockscreen require-unlock false
    gsettings set org.gnome.desktop.lockdown disable-lock-screen true
    gsettings set org.gnome.desktop.screensaver lock-enabled false
    gsettings set org.gnome.desktop.session idle-delay 0
    gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type \"nothing\"
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type \"nothing\"
' 2>/dev/null" || true

# 19. Start AMOLED Idle and Power Button Daemon (60s sleep timeout)
systemctl start poco-power-daemon.service 2>/dev/null || true

# 20. Launch POCO System Monitor Dashboard
if ! pgrep -f "poco-dashboard" >/dev/null 2>&1; then
    echo "[*] Launching POCO System Monitor Dashboard on display (with auto-restart)..."
    sleep 2
    DBUS_ADDR=$(cat /proc/$(pgrep -u poco phosh | head -n1)/environ 2>/dev/null | tr "\0" "\n" | grep DBUS | cut -d= -f2-)
    [ -z "$DBUS_ADDR" ] && DBUS_ADDR="unix:path=/run/user/1000/bus"
    su - poco -c "nohup bash -c 'while true; do DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR WAYLAND_DISPLAY=wayland-0 GSK_RENDERER=cairo GTK_A11Y=none XDG_RUNTIME_DIR=$RUNTIME_DIR /usr/local/bin/poco-dashboard; sleep 2; done' </dev/null >/var/log/poco-dashboard.log 2>&1 &"
fi

# 21. Trigger touch driver check
if [ -x /usr/local/bin/setup_touch.sh ]; then
    /usr/local/bin/setup_touch.sh > /var/log/touch_init.log 2>&1 &
fi

echo "=== GNOME Mobile Desktop & System Dashboard active ==="
echo "  Physical Screen : /dev/dri/card0 (AMOLED 1080x2400 @ GNOME Mobile / Phosh)"
echo "  System Monitor  : POCO Dashboard (CPU, RAM, Disco 104GB, Batería)"
echo "  Screen Sleep    : 60 seconds auto-sleep (Power button toggles screen)"
echo "  VNC Server      : Port 5900 (wayvnc, direct Wayland capture)"
echo "  Web noVNC (SSL) : Port 6080 (https://<ip>:6080/vnc.html)"
