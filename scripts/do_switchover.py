import socket
import time
import sys

def run_telnet_cmd(cmd, timeout=25):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(("172.16.42.1", 23))
    time.sleep(0.3)
    s.settimeout(0.5)
    try:
        s.recv(1024)
    except:
        pass

    s.sendall(cmd.encode('utf-8') + b"\nexit\n")
    output = b""
    s.settimeout(timeout)
    while True:
        try:
            data = s.recv(4096)
            if not data:
                break
            output += data
        except socket.timeout:
            break

    cleaned = output.decode('utf-8', errors='ignore')
    for line in cleaned.splitlines():
        if not line.startswith("\xff") and not "Escape character" in line and not "Trying" in line and not "Connected to" in line:
            print(line)
    s.close()
    return cleaned

if __name__ == "__main__":
    print("[*] 1. Checking current sysroot status...")
    run_telnet_cmd("ls -ld /sysroot /sysroot/ubuntu_rootfs")

    print("\n[*] 2. Stopping Debian userland daemons...")
    run_telnet_cmd("killall -9 xrdp xrdp-sesman dbus-daemon nginx sshd udisksd upowerd accounts-daemon polkitd 2>/dev/null || true")

    print("\n[*] 3. Executing atomic move (Debian -> debian_backup, Ubuntu -> /sysroot)...")
    switch_cmd = (
        "mkdir -p /sysroot/debian_backup && "
        "for d in bin boot etc home lib opt root sbin srv usr var; do "
        "if [ -e /sysroot/$d ]; then mv /sysroot/$d /sysroot/debian_backup/; fi; "
        "done && "
        "for item in /sysroot/ubuntu_rootfs/*; do "
        "b=$(basename $item); mv $item /sysroot/$b; "
        "done && "
        "rm -rf /sysroot/ubuntu_rootfs && "
        "mkdir -p /sysroot/run/sshd /sysroot/var/empty /sysroot/tmp /sysroot/mnt /sysroot/apex /sysroot/data && "
        "chmod 0755 /sysroot/run/sshd /sysroot/var/empty && "
        "echo SWITCHOVER_SUCCESS"
    )
    res = run_telnet_cmd(switch_cmd, timeout=30)

    print("\n[*] 4. Launching Ubuntu 26.04 SSHD...")
    run_telnet_cmd("chroot /sysroot /usr/sbin/sshd && ps | grep sshd", timeout=10)

    print("\n[*] 5. Verifying /etc/os-release in /sysroot...")
    run_telnet_cmd("cat /sysroot/etc/os-release", timeout=5)
