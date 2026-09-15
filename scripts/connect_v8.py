import socket
import time
import subprocess
import sys

print("[*] Starting POCO F4 v8 Connect Monitor...")

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

    # 2. Try Netcat on port 2323 (Raw TCP shell)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect(("172.16.42.1", 2323))
        print(f"\n{'='*60}\n[+] [{elapsed}s] NETCAT SHELL CONNECTED (172.16.42.1:2323)!\n{'='*60}\n")
        time.sleep(0.3)
        s.sendall(b"uname -a; id; df -h; ip a; mount | grep sda34\n")
        time.sleep(1.0)
        resp = s.recv(8192)
        print("[+] Shell Output:\n", resp.decode('utf-8', errors='ignore'))
        s.close()
        sys.exit(0)
    except:
        pass

    # 3. Try Telnet on port 23
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect(("172.16.42.1", 23))
        print(f"\n{'='*60}\n[+] [{elapsed}s] TELNET CONNECTED (172.16.42.1:23)!\n{'='*60}\n")
        time.sleep(0.3)
        s.sendall(b"uname -a; id; df -h; ip a; mount | grep sda34\n")
        time.sleep(1.0)
        resp = s.recv(8192)
        print("[+] Telnet Output:\n", resp.decode('utf-8', errors='ignore'))
        s.close()
        sys.exit(0)
    except:
        pass

    # 4. Try SSH on port 22
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.4)
        s.connect(("172.16.42.1", 22))
        print(f"\n{'='*60}\n[+] [{elapsed}s] SSH PORT 22 IS OPEN!\n{'='*60}\n")
        s.close()
        out = run_cmd("ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=3 root@172.16.42.1 'uname -a; id; df -h'")
        print("[+] SSH Output:\n", out)
        sys.exit(0)
    except:
        pass

    if i % 5 == 0:
        print(f"[{elapsed}s] Monitoring... (Interfaces: {len(configured_interfaces)})", flush=True)
    time.sleep(1)

print("[-] Monitor completed.")
