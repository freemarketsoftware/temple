#!/usr/bin/env python3
"""
Phase 2 — SerProto.HC test runner.

Protocol:
  TempleOS sends "READY\\n" when it's about to start each test batch.
  Python reads READY, then collects EOT-delimited responses.

TX tests (no host input needed):
  SerSend("hello")  -> b'hello'
  SerSendOk()       -> b'OK'
  SerSendErr("oops")-> b'ERR:oops'
  (SerSendInt dropped per 2026-02-19 decision — all responses are strings)

RX test (Python sends a line, TempleOS reads + echoes):
  Python sends b'hello\\n' -> SerRecvLine reads "hello" -> SerSend("hello") -> b'hello'

Usage:
  Terminal 1: python3 serial/test_serproto.py
  Terminal 2: ./serial/run_serproto_tests.sh
"""

import socket
import sys
import time

SOCK = '/tmp/temple-serial.sock'
EOT = 0x04
READY_TIMEOUT = 900  # covers #include SerProto.HC load time
RESPONSE_TIMEOUT = 30  # all TX tests are a single short REPL line

TX_EXPECTED = [b'hello', b'OK', b'ERR:oops']
RX_SEND = b'hello\n'
RX_EXPECTED = b'hello'


def connect():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(SOCK)
    except FileNotFoundError:
        print(f"ERROR: {SOCK} not found. Run ./start_with_serial.sh first.")
        sys.exit(1)
    print(f"[+] Connected to {SOCK}", flush=True)
    return s


class Reader:
    """Buffered reader that yields lines and EOT-delimited responses."""
    def __init__(self, sock):
        self.s = sock
        self.buf = b''

    def _fill(self, timeout):
        self.s.settimeout(timeout)
        chunk = self.s.recv(256)
        if not chunk:
            raise ConnectionError("Socket closed")
        self.buf += chunk

    def wait_for_ready(self, timeout=READY_TIMEOUT):
        """Block until a line containing READY is received."""
        print(f"[+] Waiting for READY (up to {timeout}s)...", flush=True)
        deadline = time.time() + timeout
        while True:
            remaining = deadline - time.time()
            if remaining <= 0:
                raise TimeoutError("Timed out waiting for READY")
            try:
                self._fill(remaining)
            except socket.timeout:
                raise TimeoutError("Timed out waiting for READY")
            while b'\n' in self.buf:
                line, self.buf = self.buf.split(b'\n', 1)
                print(f"  (pre-READY) {line!r}", flush=True)
                if b'READY' in line:
                    print("[+] Got READY", flush=True)
                    return

    def read_eot_responses(self, count, timeout=RESPONSE_TIMEOUT):
        """Read `count` EOT-delimited responses."""
        responses = []
        current = b''
        deadline = time.time() + timeout
        while len(responses) < count:
            remaining = deadline - time.time()
            if remaining <= 0:
                raise TimeoutError(f"Timed out after {len(responses)}/{count} responses")
            # Check buffer first
            eot_pos = self.buf.find(bytes([EOT]))
            if eot_pos != -1:
                current += self.buf[:eot_pos]
                self.buf = self.buf[eot_pos + 1:]
                responses.append(current)
                print(f"  <- response {len(responses)}: {current!r}", flush=True)
                current = b''
                continue
            current += self.buf
            self.buf = b''
            try:
                self._fill(remaining)
            except socket.timeout:
                raise TimeoutError(f"Timed out after {len(responses)}/{count} responses")
        return responses


def run_tx_tests(reader):
    print("\n--- TX Tests ---", flush=True)
    reader.wait_for_ready()
    print(f"[+] Reading {len(TX_EXPECTED)} EOT responses...", flush=True)
    responses = reader.read_eot_responses(len(TX_EXPECTED))

    passed = True
    for i, (got, exp) in enumerate(zip(responses, TX_EXPECTED)):
        ok = got == exp
        print(f"  TX[{i+1}]: {'PASS' if ok else 'FAIL'}  got={got!r}  expected={exp!r}")
        if not ok:
            passed = False
    return passed


def run_rx_test(reader, sock):
    print("\n--- RX Test (SerRecvLine) ---", flush=True)
    reader.wait_for_ready()
    print(f"[+] Sending {RX_SEND!r}...", flush=True)
    sock.sendall(RX_SEND)
    responses = reader.read_eot_responses(1)
    got = responses[0] if responses else b''
    ok = got == RX_EXPECTED
    print(f"  RX:    {'PASS' if ok else 'FAIL'}  got={got!r}  expected={RX_EXPECTED!r}")
    return ok


def main():
    s = connect()
    reader = Reader(s)

    tx_ok = False
    rx_ok = False
    try:
        tx_ok = run_tx_tests(reader)
        rx_ok = run_rx_test(reader, s)
    except (TimeoutError, ConnectionError) as e:
        print(f"\nFAIL: {e}")
        s.close()
        sys.exit(1)

    s.close()
    print()
    all_ok = tx_ok and rx_ok
    print("RESULT:", "PASS — Phase 2 SerProto.HC verified." if all_ok else "FAIL — see above")
    sys.exit(0 if all_ok else 1)


if __name__ == '__main__':
    main()
