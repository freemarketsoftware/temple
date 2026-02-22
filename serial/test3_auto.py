#!/usr/bin/env python3
"""
Phase 1 — Test 3 automated: RX test (Host -> Guest -> Host).
Tests UartGetChar / UartRxReady on TempleOS.

Protocol:
  TempleOS sends "READY\n" once UartInit is done and the RX loop is about to start.
  Host receives "READY\n", then sends "HELLO" (5 bytes).
  TempleOS echoes each byte as "ECHO:X\n".
  Host verifies all 5 echoes.

Usage:
  Terminal 1: python3 serial/test3_auto.py      (connect first, holds socket)
  Terminal 2: ./serial/send_test3.sh            (types HolyC into TempleOS)
"""

import socket
import sys
import time

SOCK = '/tmp/temple-serial.sock'
READY_TIMEOUT = 120  # seconds to wait for TempleOS to send READY (covers slow typing)
ECHO_TIMEOUT = 15    # seconds to wait for all 5 echoes after sending HELLO


def connect():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(SOCK)
    except FileNotFoundError:
        print(f"ERROR: Socket not found: {SOCK}")
        print("       Run ./start_with_serial.sh first.")
        sys.exit(1)
    print(f"[+] Connected to {SOCK}", flush=True)
    return s


def wait_for_ready(s):
    """Read lines until we see one containing READY, with READY_TIMEOUT."""
    print(f"[+] Waiting up to {READY_TIMEOUT}s for READY from TempleOS...", flush=True)
    buf = b''
    deadline = time.time() + READY_TIMEOUT
    while True:
        remaining = deadline - time.time()
        if remaining <= 0:
            raise TimeoutError("Timed out waiting for READY from TempleOS")
        s.settimeout(remaining)
        try:
            chunk = s.recv(64)
        except socket.timeout:
            raise TimeoutError("Timed out waiting for READY from TempleOS")
        if not chunk:
            raise ConnectionError("Socket closed while waiting for READY")
        buf += chunk
        while b'\n' in buf:
            line, buf = buf.split(b'\n', 1)
            print(f"  (pre-READY) {line!r}", flush=True)
            if b'READY' in line:
                print("[+] Got READY — sending HELLO", flush=True)
                return


def read_echoes(s):
    """Read 5 ECHO:X lines, ignoring others, within ECHO_TIMEOUT."""
    lines = []
    buf = b''
    deadline = time.time() + ECHO_TIMEOUT
    while len(lines) < 5:
        remaining = deadline - time.time()
        if remaining <= 0:
            break
        s.settimeout(remaining)
        try:
            chunk = s.recv(64)
        except socket.timeout:
            break
        if not chunk:
            break
        buf += chunk
        while b'\n' in buf:
            line, buf = buf.split(b'\n', 1)
            if line.startswith(b'ECHO:'):
                lines.append(line)
                print(f"  <- {line!r}", flush=True)
            else:
                print(f"  (ignored) {line!r}", flush=True)
            if len(lines) >= 5:
                break
    return lines


def main():
    s = connect()

    try:
        wait_for_ready(s)
    except (TimeoutError, ConnectionError) as e:
        print(f"\nFAIL: {e}")
        s.close()
        sys.exit(1)

    s.sendall(b'HELLO')
    print(f"[+] Sent: b'HELLO'", flush=True)

    print(f"[+] Reading 5 ECHO: lines (timeout {ECHO_TIMEOUT}s)...", flush=True)
    lines = read_echoes(s)
    s.close()

    expected = [b'ECHO:H', b'ECHO:E', b'ECHO:L', b'ECHO:L', b'ECHO:O']
    print()
    passed = True

    if len(lines) < 5:
        print(f"FAIL: only received {len(lines)}/5 echo lines")
        passed = False
    else:
        for i, (got, exp) in enumerate(zip(lines, expected)):
            status = "PASS" if got == exp else "FAIL"
            print(f"  line {i+1}: {status}  got={got!r}  expected={exp!r}")
            if got != exp:
                passed = False

    print()
    if passed:
        print("RESULT: PASS — Test 3 complete. Phase 1 RX path verified.")
    else:
        print("RESULT: FAIL — see lines above")

    sys.exit(0 if passed else 1)


if __name__ == '__main__':
    main()
