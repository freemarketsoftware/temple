#!/usr/bin/env python3
"""
Ed diagnostic: listens on serial for EDOK + EOT.

If Ed saved TestEdDiag.HC correctly, TempleOS will output:
  b'EDOK' followed by EOT (byte 4)

Usage:
  Terminal 1: python3 serial/test_ed_check.py
  Terminal 2: ./serial/test_ed_write.sh
"""

import socket
import sys
import time

SOCK = '/tmp/temple-serial.sock'
EOT = 0x04
TIMEOUT = 600  # 10 min — covers all typing time


def main():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(SOCK)
    except FileNotFoundError:
        print(f"ERROR: {SOCK} not found. Run ./start_with_serial.sh first.")
        sys.exit(1)
    print(f"[+] Connected to {SOCK}")
    print(f"[+] Waiting up to {TIMEOUT}s for EDOK response...")

    buf = b''
    deadline = time.time() + TIMEOUT
    s.settimeout(1.0)

    while True:
        remaining = deadline - time.time()
        if remaining <= 0:
            print("FAIL: Timed out waiting for EDOK")
            s.close()
            sys.exit(1)
        try:
            chunk = s.recv(256)
            if not chunk:
                print("FAIL: Socket closed unexpectedly")
                s.close()
                sys.exit(1)
            buf += chunk
        except socket.timeout:
            continue

        # Print any new bytes for visibility
        # Check for EOT-delimited response
        eot_pos = buf.find(bytes([EOT]))
        if eot_pos != -1:
            response = buf[:eot_pos]
            buf = buf[eot_pos + 1:]
            print(f"[+] Got response: {response!r}")
            if response == b'EDOK':
                print("PASS: Ed wrote the file and it executed correctly.")
                s.close()
                sys.exit(0)
            else:
                print(f"FAIL: Expected b'EDOK', got {response!r}")
                s.close()
                sys.exit(1)


if __name__ == '__main__':
    main()
