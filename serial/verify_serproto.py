#!/usr/bin/env python3
"""
Verifies SerProto.HC was written correctly.
Waits for READY, then expects 'PROTO_OK' + EOT.
"""
import socket, sys, time

SOCK = '/tmp/temple-serial.sock'
EOT = 0x04
READY_TIMEOUT = 900
RESPONSE_TIMEOUT = 60

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

deadline = time.time() + RESPONSE_TIMEOUT
while time.time() < deadline:
    try:
        chunk = s.recv(256)
        if chunk:
            buf += chunk
            if EOT in buf:
                response = buf[:buf.index(EOT)].lstrip(b'\n\r')
                print(f"[+] Got response: {response!r}", flush=True)
                if response == b'PROTO_OK':
                    print("PASS: SerProto.HC is working.")
                else:
                    print(f"FAIL: Expected b'PROTO_OK', got {response!r}")
                s.close()
                sys.exit(0)
    except socket.timeout:
        continue

print("FAIL: Timed out waiting for response")
s.close()
sys.exit(1)
