import subprocess
import time
import socket
import os

print("[*] Starting boot monitor...")
start_time = time.time()

def check_ip_link():
    try:
        out = subprocess.check_output(['ip', '-br', 'link'], text=True)
        return out
    except:
        return ""

def check_fastboot():
    try:
        out = subprocess.check_output(['./platform-tools/fastboot', 'devices'], text=True, timeout=1)
        return out.strip()
    except:
        return ""

def check_adb():
    try:
        out = subprocess.check_output(['./platform-tools/adb', 'devices'], text=True, timeout=1)
        lines = [l for l in out.splitlines() if l.strip() and not l.startswith('List')]
        return "\n".join(lines)
    except:
        return ""

def check_ssh_port(ip, port=22, timeout=0.4):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect((ip, port))
        s.close()
        return True
    except:
        return False

initial_links = set(check_ip_link().splitlines())
print(f"[*] Baseline network links: {len(initial_links)}")

known_ips = {'192.168.100.1', '192.168.100.2', '192.168.100.7'}

for i in range(60):
    elapsed = int(time.time() - start_time)
    
    # Check fastboot
    fb = check_fastboot()
    if fb:
        print(f"[{elapsed}s] Device in FASTBOOT: {fb}")
        break
    
    # Check ADB
    ad = check_adb()
    if ad:
        print(f"[{elapsed}s] Device in ADB: {ad}")
    
    # Check new USB links
    current_links = set(check_ip_link().splitlines())
    new_links = current_links - initial_links
    if new_links:
        print(f"[{elapsed}s] !!! NEW USB NETWORK INTERFACE DETECTED !!!: {new_links}")
        for nl in new_links:
            ifname = nl.split()[0]
            print(f"[*] Detected interface {ifname}")
            if check_ssh_port('172.16.42.1'):
                print(f"[{elapsed}s] *** SSH CONNECTED ON USB GADGET: 172.16.42.1:22 ***")

    # Ping sweep local network briefly every 10s to discover new Wi-Fi devices
    if i % 5 == 0:
        subprocess.run("for ip in $(seq 10 50); do ping -c 1 -W 1 192.168.100.$ip >/dev/null 2>&1 & done", shell=True)

    # Check ARP / Wi-Fi subnet
    try:
        arp = subprocess.check_output(['ip', 'neigh', 'show'], text=True)
        for line in arp.splitlines():
            if '192.168.100.' in line and ('REACHABLE' in line or 'DELAY' in line):
                ip = line.split()[0]
                if ip not in known_ips:
                    print(f"[{elapsed}s] Discovered active Wi-Fi IP: {ip}")
                    if check_ssh_port(ip):
                        print(f"[{elapsed}s] *** SSH DETECTED ON WIFI: {ip}:22 ***")
    except:
        pass
    
    time.sleep(2)

print("[*] Monitor cycle completed.")
