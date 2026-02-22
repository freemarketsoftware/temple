#!/usr/bin/env python3
"""
Reads a file from TempleOS via serial.
Expects EOT (0x04) as end-of-file marker.
Usage: python3 read_file.py <output_file>
"""
import socket, sys, time

SOCK = '/tmp/temple-serial.sock'
EOT = 0x04
READY_TIMEOUT = 300
DATA_TIMEOUT = 60

out = sys.argv[1] if len(sys.argv) > 1 else '/tmp/temple_file.txt'

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(SOCK)
print(f"[+] Connected. Waiting for READY...")
s.settimeout(1.0)

buf = b''
deadline = time.time() + READY_TIMEOUT
while time.time() < deadline:
    try:
        chunk = s.recv(4096)
        if chunk:
            buf += chunk
            if b'READY' in buf:
                print("[+] Got READY, waiting for file data...")
                buf = b''
                break
    except socket.timeout:
        continue

# Read until EOT
deadline = time.time() + DATA_TIMEOUT
while time.time() < deadline:
    try:
        chunk = s.recv(4096)
        if chunk:
            buf += chunk
            if EOT in buf:
                eot = buf.index(EOT)
                data = buf[:eot]
                with open(out, 'wb') as f:
                    f.write(data)
                print(f"[+] Saved {len(data)} bytes to {out}")
                print("--- content ---")
                print(data.decode('latin-1', errors='replace'))
                print("--- end ---")
                s.close()
                sys.exit(0)
    except socket.timeout:
        continue

print("TIMEOUT waiting for data")
s.close()
sys.exit(1)
