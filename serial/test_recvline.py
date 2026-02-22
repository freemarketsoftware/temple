#!/usr/bin/env python3
"""
Phase 2 — SerRecvLine test.
Waits for READY, sends 'hello\n', expects 'hello\x04' back.
"""
import socket, sys, time

SOCK = '/tmp/temple-serial.sock'
EOT = 0x04
READY_TIMEOUT = 600
RESPONSE_TIMEOUT = 120

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(SOCK)
print("[+] Connected. Waiting for READY...", flush=True)
s.settimeout(1.0)

buf = b''
deadline = time.time() + READY_TIMEOUT
while time.time() < deadline:
    try:
        chunk = s.recv(256)
        if chunk:
            buf += chunk
            if b'READY' in buf:
                print("[+] Got READY", flush=True)
                buf = b''
                break
    except socket.timeout:
        continue
else:
    print("FAIL: Timed out waiting for READY")
    sys.exit(1)

print("[+] Sending 'hello\\n'...", flush=True)
s.sendall(b'hello\n')

deadline = time.time() + RESPONSE_TIMEOUT
while time.time() < deadline:
    try:
        chunk = s.recv(256)
        if chunk:
            buf += chunk
            if EOT in buf:
                response = buf[:buf.index(EOT)].lstrip(b'\n\r')
                print(f"[+] Got response: {response!r}", flush=True)
                if response == b'hello':
                    print("PASS: SerRecvLine works.")
                else:
                    print(f"FAIL: Expected b'hello', got {response!r}")
                s.close()
                sys.exit(0)
    except socket.timeout:
        continue

print("FAIL: Timed out waiting for response")
s.close()
sys.exit(1)
