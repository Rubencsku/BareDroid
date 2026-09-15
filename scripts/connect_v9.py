import socket
import time
import subprocess
import sys

print("[*] Starting POCO F4 v9 Boot & Wi-Fi Monitor...")

start_time = time.time()
configured_interfaces = set()

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)
    except Exception as e:
        return str(e)

for i in range(150):
    elapsed = int(time.time() - start_time)

    # 1. Detect USB Network Interface
    ip_link = run_cmd("ip -br link")
    for line in ip_link.splitlines():
        parts = line.split()
        if not parts:
            continue
        ifname = parts[0]
        if ifname.startswith("enx") and ifname not in configured_interfaces:
            print(f"[{elapsed}s] Detected USB Gadget Interface: {ifname}")
            configured_interfaces.add(ifname)
            run_cmd(f"nmcli con add type ethernet ifname {ifname} con-name 'poco-{ifname}' ip4 172.16.42.2/24 2>/dev/null")
            run_cmd(f"nmcli con up 'poco-{ifname}' 2>/dev/null")
            print(f"[{elapsed}s] Assigned 172.16.42.2/24 to {ifname}")

    # 2. Try SSH on USB (172.16.42.1:22)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.4)
        s.connect(("172.16.42.1", 22))
        s.close()
        print(f"\n{'='*60}\n[+] [{elapsed}s] SSH PORT 22 IS OPEN ON USB (172.16.42.1)!\n{'='*60}\n")
        out = run_cmd("ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=3 root@172.16.42.1 'uptime; ip a; cat /root/wifi_ip.txt 2>/dev/null || echo \"No wifi ip yet\"'")
        print("[+] System Info:\n", out)
        break
    except:
        pass

    # 3. Try Telnet on USB (172.16.42.1:23)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.4)
        s.connect(("172.16.42.1", 23))
        s.close()
        print(f"[{elapsed}s] Telnet is open on 172.16.42.1:23")
    except:
        pass

    if i % 5 == 0:
        print(f"[{elapsed}s] Monitoring boot... (Interfaces: {len(configured_interfaces)})", flush=True)
    time.sleep(1)

print("[*] Monitor finished initial phase.")
