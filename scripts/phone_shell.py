import socket
import time
import sys

def run_telnet(cmd, timeout=3.0):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(2.0)
    s.connect(("172.16.42.1", 23))
    
    # Read initial greeting
    time.sleep(0.3)
    try:
        s.recv(4096)
    except:
        pass

    # Send command
    s.sendall(cmd.encode() + b"\n")
    time.sleep(0.5)
    
    out = b""
    end_time = time.time() + timeout
    while time.time() < end_time:
        try:
            s.settimeout(0.5)
            chunk = s.recv(4096)
            if not chunk:
                break
            out += chunk
        except socket.timeout:
            if out:
                break
        except:
            break
    s.close()
    
    text = out.decode("latin1", errors="ignore")
    # Clean up telnet control bytes
    clean = ""
    for c in text:
        if ord(c) < 32 and c not in "\n\r\t":
            continue
        clean += c
    return clean

if __name__ == "__main__":
    cmd = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "uptime"
    print(run_telnet(cmd))
