import socket, threading, select

def handle_client(client_socket):
    try:
        request = client_socket.recv(4096)
        if not request:
            client_socket.close()
            return
        first_line = request.split(b'\r\n')[0].decode('ascii', errors='ignore')
        method, target, _ = first_line.split(' ')
        if method == 'CONNECT':
            host, port = target.split(':')
            server_socket = socket.create_connection((host, int(port)), timeout=10)
            client_socket.sendall(b'HTTP/1.1 200 Connection Established\r\n\r\n')
        else:
            # Standard HTTP GET/POST
            url = target
            if url.startswith('http://'):
                url = url[7:]
            host = url.split('/')[0]
            port = 80
            if ':' in host:
                host, p = host.split(':')
                port = int(p)
            server_socket = socket.create_connection((host, port), timeout=10)
            server_socket.sendall(request)
        
        # Bi-directional forwarding
        sockets = [client_socket, server_socket]
        while True:
            r, _, _ = select.select(sockets, [], [], 30)
            if not r:
                break
            for s in r:
                other = server_socket if s is client_socket else client_socket
                data = s.recv(8192)
                if not data:
                    return
                other.sendall(data)
    except Exception:
        pass
    finally:
        client_socket.close()
        try: server_socket.close()
        except: pass

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('0.0.0.0', 8888))
server.listen(100)
print("[*] Proxy listening on 0.0.0.0:8888")

while True:
    client, _ = server.accept()
    threading.Thread(target=handle_client, args=(client,), daemon=True).start()
