#!/usr/bin/env python3
"""
Minimal SerRepl verify — just tests REPL_READY + echo-OK loop.
SerRepl (minimal version) sends OK for any command.
"""
import socket, sys, time

SOCK = '/tmp/temple-serial.sock'
EOT = 0x04
READY_TIMEOUT = 900
RESPONSE_TIMEOUT = 60

def read_response(s, timeout=RESPONSE_TIMEOUT):
    buf = b''
    deadline = time.time() + timeout
    s.settimeout(1.0)
    while time.time() < deadline:
        try:
            chunk = s.recv(256)
            if chunk:
                buf += chunk
                if EOT in buf:
                    eot = buf.index(EOT)
                    resp = buf[:eot].lstrip(b'\n\r')
                    remainder = buf[eot+1:]
                    return resp, remainder
        except socket.timeout:
            continue
    return None, b''

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(SOCK)
print("[+] Connected. Waiting for REPL_READY...", flush=True)
s.settimeout(1.0)

buf = b''
deadline = time.time() + READY_TIMEOUT
while time.time() < deadline:
    try:
        chunk = s.recv(256)
        if chunk:
            buf += chunk
            if b'REPL_READY' in buf:
                print("[+] Got REPL_READY — compilation OK!", flush=True)
                buf = b''
                break
    except socket.timeout:
        continue
else:
    print("FAIL: Timed out waiting for REPL_READY")
    sys.exit(1)

# Test basic echo loop — minimal REPL sends OK for any command
print("[>] Sending dummy command 'SerSendOk();'...", flush=True)
s.sendall(b'SerSendOk();\n')
resp, _ = read_response(s)
if resp == b'OK':
    print("PASS: Got OK back")
else:
    print(f"FAIL: Expected b'OK', got {resp!r}")

print("[+] Sending EXIT...", flush=True)
s.sendall(b'EXIT\n')
s.close()
print("Done.")
