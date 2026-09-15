import socket
import time
import subprocess
import sys
import re

print("[*] Starting POCO F4 v7 Boot & Connect Monitor...")

start_time = time.time()
configured_interfaces = set()

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)
    except Exception as e:
        return str(e)

for i in range(120):
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
            # Ping multicast IPv6 to force neighbor discovery
            run_cmd(f"ping -6 -c 2 ff02::1%{ifname} >/dev/null 2>&1 &")

    # 2. Try Telnet via IPv4 (172.16.42.1:23)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.4)
        s.connect(("172.16.42.1", 23))
        print(f"\n{'='*60}\n[+] [{elapsed}s] TELNET CONNECTED TO POCO F4 (IPv4: 172.16.42.1:23)!\n{'='*60}\n")
        time.sleep(0.3)
        s.sendall(b"echo '=== HARDWARE PROBE ==='; uname -a; id; df -h; ip a; cat /proc/partitions | head -n 30\n")
        time.sleep(1.2)
        resp = s.recv(8192)
        print("[+] POCO F4 Shell Output:\n", resp.decode('utf-8', errors='ignore'))
        s.close()
        sys.exit(0)
    except:
        pass

    # 3. Try Telnet via IPv6 Link-Local
    neigh = run_cmd("ip -6 neigh show")
    for line in neigh.splitlines():
        if 'enx' in line and ('REACHABLE' in line or 'DELAY' in line or 'STALE' in line):
            parts = line.split()
            ip6 = parts[0]
            dev = [p for p in parts if p.startswith('enx')][0]
            try:
                s6 = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
                s6.settimeout(0.4)
                idx = socket.if_nametoindex(dev)
                s6.connect((ip6, 23, 0, idx))
                print(f"\n{'='*60}\n[+] [{elapsed}s] TELNET CONNECTED TO POCO F4 (IPv6: [{ip6}%{dev}]:23)!\n{'='*60}\n")
                time.sleep(0.3)
                s6.sendall(b"echo '=== HARDWARE PROBE ==='; uname -a; id; df -h; ip a; cat /proc/partitions | head -n 30\n")
                time.sleep(1.2)
                resp = s6.recv(8192)
                print("[+] POCO F4 Shell Output:\n", resp.decode('utf-8', errors='ignore'))
                s6.close()
                sys.exit(0)
            except:
                pass

    if i % 5 == 0:
        print(f"[{elapsed}s] Monitoring boot... (Interfaces: {len(configured_interfaces)})", flush=True)
    time.sleep(1)

print("[-] Monitor completed.")
