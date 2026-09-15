import socket
import time
import subprocess
import sys
import os
import shlex

print("[*] Starting POCO F4 Autonomous Boot & Wi-Fi Monitor...")

start_time = time.time()
configured_interfaces = set()

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)
    except Exception as e:
        return str(e)

wifi_connected = False
ssh_connected = False
wifi_host = os.environ.get("BAREDROID_HOST", "poco-server.local")
wifi_ssh_target = shlex.quote(f"root@{wifi_host}")

for i in range(120):
    elapsed = int(time.time() - start_time)

    # 1. Detect USB Network Interface
    ip_link = run_cmd("ip -br link")
    for line in ip_link.splitlines():
        parts = line.split()
        if not parts:
            continue
        ifname = parts[0]
        if (ifname.startswith("enx") or ifname.startswith("usb")) and ifname not in configured_interfaces:
            print(f"[{elapsed}s] Detected USB Gadget Interface: {ifname}")
            configured_interfaces.add(ifname)
            run_cmd(f"nmcli con add type ethernet ifname {ifname} con-name 'poco-{ifname}' ip4 172.16.42.2/24 2>/dev/null")
            run_cmd(f"nmcli con up 'poco-{ifname}' 2>/dev/null")
            print(f"[{elapsed}s] Assigned 172.16.42.2/24 to {ifname}")

    # 2. Check Wi-Fi SSH
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.4)
        s.connect((wifi_host, 22))
        s.close()
        print(f"\n{'='*60}\n[+] [{elapsed}s] SSH PORT 22 IS OPEN OVER WI-FI ({wifi_host})!\n{'='*60}\n")
        out = run_cmd(f"ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 {wifi_ssh_target} 'uptime; ip a; cat /var/log/wifi_boot.log | tail -n 15'")
        print("[+] Wi-Fi & System Status:\n", out)
        wifi_connected = True
        break
    except:
        pass

    # 3. Check USB SSH (172.16.42.1:22)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.4)
        s.connect(("172.16.42.1", 22))
        s.close()
        if not ssh_connected:
            print(f"[{elapsed}s] SSH is open on USB (172.16.42.1)")
            ssh_connected = True
    except:
        pass

    # 4. Check USB Telnet (172.16.42.1:23)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.4)
        s.connect(("172.16.42.1", 23))
        s.close()
    except:
        pass

    if i % 5 == 0:
        print(f"[{elapsed}s] Waiting for Wi-Fi association... (USB reachable: {ssh_connected})", flush=True)
    time.sleep(1)

if not wifi_connected:
    print("[!] Timed out waiting for Wi-Fi, checking USB diagnostic...")
    out = run_cmd("ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 root@172.16.42.1 'uptime; ip a; cat /var/log/wifi_boot.log | tail -n 25'")
    print(out)
