import socket
import time
import sys

cmd = sys.argv[1] if len(sys.argv) > 1 else "uname -a"

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("172.16.42.1", 23))
time.sleep(0.3)
# Read initial telnet negotiation and banner
s.settimeout(0.5)
try:
    s.recv(1024)
except:
    pass

s.sendall(cmd.encode('utf-8') + b"\nexit\n")
time.sleep(0.5)

output = b""
s.settimeout(2.0)
while True:
    try:
        data = s.recv(4096)
        if not data:
            break
        output += data
    except socket.timeout:
        break

# Filter out telnet control codes
cleaned = output.decode('utf-8', errors='ignore')
for line in cleaned.splitlines():
    if not line.startswith("\xff") and not "Escape character" in line and not "Trying" in line and not "Connected to" in line:
        print(line)

s.close()
