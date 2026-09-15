#!/usr/bin/env bash
# Connect to the optional POCO F4 remote desktop.
# Supported modes: web (noVNC), RDP (Remmina/FreeRDP) and VNC.

MODE="${1:-web}"
TARGET="${2:-wifi}"

if [ "$TARGET" = "usb" ]; then
    IP="172.16.42.1"
else
    IP="${BAREDROID_HOST:-poco-server.local}"
fi

echo "====================================================="
echo "   POCO F4 GNOME Desktop - Remote access ($TARGET)   "
echo "====================================================="
echo "Server          : $IP"
echo "User            : poco"
echo "Password        : configured by the user on the target"
echo "-----------------------------------------------------"

case "$MODE" in
    web|browser)
        URL="http://${IP}:6080/vnc.html?autoconnect=true&resize=remote"
        echo "[*] Opening the GNOME desktop in a web browser ($URL)..."
        if which xdg-open >/dev/null 2>&1; then
            xdg-open "$URL"
        elif which sensible-browser >/dev/null 2>&1; then
            sensible-browser "$URL"
        else
            echo "Open this URL in a browser: $URL"
        fi
        ;;

    rdp)
        echo "[*] Connecting to RDP at ${IP}:3389..."
        if which remmina >/dev/null 2>&1; then
            remmina -c "rdp://${IP}:3389" >/dev/null 2>&1 &
        elif which xfreerdp >/dev/null 2>&1; then
            xfreerdp /v:${IP}:3389 /u:poco /dynamic-resolution /cert:ignore +clipboard &
        else
            echo "No RDP client was found (Remmina or FreeRDP)."
            echo "Use an RDP client to connect to ${IP}:3389."
        fi
        ;;

    vnc)
        echo "[*] Connecting to VNC at ${IP}:5901..."
        if which vncviewer >/dev/null 2>&1; then
            vncviewer "${IP}:5901" &
        elif which remmina >/dev/null 2>&1; then
            remmina -c "vnc://${IP}:5901" >/dev/null 2>&1 &
        else
            echo "No VNC client was found (vncviewer or Remmina)."
            echo "Use a VNC client to connect to ${IP}:5901."
        fi
        ;;

    *)
        echo "Usage: $0 [web|rdp|vnc] [wifi|usb]"
        echo "Examples:"
        echo "  $0 web wifi     # Open noVNC over Wi-Fi"
        echo "  $0 rdp wifi     # Connect with Remmina or FreeRDP"
        echo "  $0 vnc wifi     # Connect with VNC"
        echo "  $0 web usb      # Open noVNC over USB (172.16.42.1)"
        ;;
esac
