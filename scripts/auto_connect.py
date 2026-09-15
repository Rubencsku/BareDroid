import socket
import time
import subprocess
import sys
import os

print("[*] Starting POCO F4 Auto-Connect...")

start_time = time.time()
configured_interfaces = set()

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)
    except Exception as e:
        return str(e)

for i in range(120):
    elapsed = int(time.time() - start_time)

    # 1. Check for any enx* interface
    ip_link = run_cmd("ip -br link")
    for line in ip_link.splitlines():
        parts = line.split()
        if not parts:
            continue
        ifname = parts[0]
        if ifname.startswith("enx") and ifname not in configured_interfaces:
            print(f"[{elapsed}s] Detected USB Gadget Network Interface: {ifname}")
            configured_interfaces.add(ifname)
            # Add network connection in NetworkManager
            run_cmd(f"nmcli con add type ethernet ifname {ifname} con-name 'poco-gadget-{ifname}' ip4 172.16.42.2/24 2>/dev/null")
            run_cmd(f"nmcli con up 'poco-gadget-{ifname}' 2>/dev/null")
            print(f"[{elapsed}s] Configured host IP 172.16.42.2/24 on {ifname}")

    # 2. Try Telnet on 172.16.42.1:23
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.4)
        s.connect(("172.16.42.1", 23))
        print(f"\n{'='*60}\n[+] [{elapsed}s] TELNET CONNECTED TO POCO F4 (172.16.42.1:23)!\n{'='*60}\n")
        time.sleep(0.3)
        s.sendall(b"uname -a; id; df -h; ip a\n")
        time.sleep(0.8)
        resp = s.recv(4096)
        print("[+] Output from POCO F4:\n", resp.decode('utf-8', errors='ignore'))
        s.close()
        sys.exit(0)
    except:
        pass

    # 3. Try SSH on 172.16.42.1:22
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.4)
        s.connect(("172.16.42.1", 22))
        print(f"\n{'='*60}\n[+] [{elapsed}s] SSH CONNECTED TO POCO F4 (172.16.42.1:22)!\n{'='*60}\n")
        s.close()
        sys.exit(0)
    except:
        pass

    # 4. Check Wi-Fi subnet
    if i % 6 == 0:
        run_cmd("for ip in $(seq 10 50); do ping -c 1 -W 1 192.168.100.$ip >/dev/null 2>&1 & done")
    
    neigh = run_cmd("ip neigh show")
    for line in neigh.splitlines():
        if '192.168.100.' in line and ('REACHABLE' in line or 'DELAY' in line):
            ip = line.split()[0]
            if ip not in ['192.168.100.1', '192.168.100.2', '192.168.100.7']:
                try:
                    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    s.settimeout(0.3)
                    s.connect((ip, 22))
                    print(f"\n{'='*60}\n[+] [{elapsed}s] SSH DETECTED ON WI-FI ({ip}:22)!\n{'='*60}\n")
                    s.close()
                    sys.exit(0)
                except:
                    pass

    if i % 5 == 0:
        print(f"[{elapsed}s] Monitoring boot... (USB & Wi-Fi)", flush=True)
    time.sleep(1)

print("[-] Monitor completed.")
