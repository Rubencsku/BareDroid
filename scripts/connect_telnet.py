import socket
import time
import sys
import subprocess

print("[*] Waiting for device on USB / Network...")

target_ip = "172.16.42.1"
start_time = time.time()

for i in range(120):
    elapsed = int(time.time() - start_time)
    
    # Try telnet port 23
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect((target_ip, 23))
        print(f"\n[+] [{elapsed}s] TELNET CONNECTED TO {target_ip}:23!")
        s.sendall(b"uname -a; id; df -h; ip a\n")
        time.sleep(0.5)
        resp = s.recv(4096)
        print("[+] Output:\n", resp.decode('utf-8', errors='ignore'))
        s.close()
        sys.exit(0)
    except Exception as e:
        pass

    # Try SSH port 22
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect((target_ip, 22))
        print(f"\n[+] [{elapsed}s] SSH CONNECTED TO {target_ip}:22!")
        s.close()
        sys.exit(0)
    except:
        pass

    # Check IPv6 neighbors on USB interface
    try:
        out = subprocess.check_output(['ip', '-6', 'neigh', 'show'], text=True)
        for line in out.splitlines():
            if 'enx' in line and ('REACHABLE' in line or 'DELAY' in line or 'STALE' in line):
                ip6 = line.split()[0]
                dev = [p for p in line.split() if p.startswith('enx')][0]
                # Try telnet on IPv6
                try:
                    s6 = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
                    s6.settimeout(0.5)
                    # Scope ID is the interface index
                    idx = socket.if_nametoindex(dev)
                    s6.connect((ip6, 23, 0, idx))
                    print(f"\n[+] [{elapsed}s] TELNET CONNECTED TO [{ip6}%{dev}]:23!")
                    s6.sendall(b"uname -a; id; df -h; ip a\n")
                    time.sleep(0.5)
                    resp = s6.recv(4096)
                    print("[+] Output:\n", resp.decode('utf-8', errors='ignore'))
                    s6.close()
                    sys.exit(0)
                except:
                    pass
    except:
        pass

    if i % 10 == 0:
        print(f"[{elapsed}s] Still waiting for telnet / ssh...", flush=True)
    time.sleep(1)

print("[-] Timeout waiting for connection.")
