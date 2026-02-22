#!/usr/bin/env python3
"""
Reads file listing and file contents from TempleOS via serial.
Expects EOT (0x04) delimited responses.
"""
import socket, sys, time

SOCK = '/tmp/temple-serial.sock'
EOT = 0x04
TIMEOUT = 30

def read_response(s, timeout=TIMEOUT):
    buf = b''
    deadline = time.time() + timeout
    s.settimeout(1.0)
    while time.time() < deadline:
        try:
            chunk = s.recv(4096)
            if not chunk:
                break
            buf += chunk
            if EOT in buf:
                eot = buf.index(EOT)
                return buf[:eot]
        except socket.timeout:
            continue
    return buf

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(SOCK)
print(f"[+] Connected")

# Wait for READY signal from TempleOS
print("[+] Waiting for READY...")
buf = b''
deadline = time.time() + 600
s.settimeout(1.0)
while time.time() < deadline:
    try:
        chunk = s.recv(256)
        if chunk:
            buf += chunk
            sys.stdout.buffer.write(chunk)
            sys.stdout.flush()
            if b'READY' in buf:
                print("\n[+] Got READY")
                break
    except socket.timeout:
        continue

# Now read all EOT-delimited responses
print("[+] Reading responses...")
while True:
    resp = read_response(s, timeout=10)
    if not resp:
        break
    print(f"RESPONSE: {resp!r}")
    print(resp.decode('latin-1', errors='replace'))
    print("---")

s.close()
print("[+] Done")
