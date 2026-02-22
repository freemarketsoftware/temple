#!/usr/bin/env python3
"""
Phase 3 — SerRepl.HC test runner.

Protocol (one EOT per command — guaranteed by g_replied flag):
  Host sends:    <HolyC code>\n
  TempleOS:      Eval(code); if g_replied==0: SerSendOk()
  Host receives: <response>\x04  (exactly one per command)

Tests:
  1. SerSend("hello")   -> b'hello'   (code calls SerSend, loop skips OK)
  2. SerSendOk()        -> b'OK'      (code calls SerSendOk->SerSend, loop skips OK)
  3. SerSendErr("bad")  -> b'ERR:bad' (code calls SerSendErr->SerSend, loop skips OK)
  4. I64 x=1+1;         -> b'OK'      (code doesn't call SerSend, loop sends fallback OK)

Usage:
  Terminal 1: python3 serial/verify_serrepl.py
  Terminal 2: ./serial/write_serrepl_ed.sh
"""
import socket, sys, time

SOCK = '/tmp/temple-serial.sock'
EOT = 0x04
READY_TIMEOUT = 900
RESPONSE_TIMEOUT = 60


def read_eot(s, leftover, timeout=RESPONSE_TIMEOUT):
    """Read bytes until EOT, return (response_bytes, new_leftover)."""
    buf = leftover
    deadline = time.time() + timeout
    s.settimeout(1.0)
    while True:
        eot_pos = buf.find(bytes([EOT]))
        if eot_pos != -1:
            return buf[:eot_pos], buf[eot_pos + 1:]
        remaining = deadline - time.time()
        if remaining <= 0:
            return None, buf
        try:
            chunk = s.recv(256)
            if chunk:
                buf += chunk
        except socket.timeout:
            continue


s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(SOCK)
print("[+] Connected. Waiting for REPL_READY...", flush=True)
s.settimeout(1.0)

leftover = b''
deadline = time.time() + READY_TIMEOUT
while time.time() < deadline:
    try:
        chunk = s.recv(256)
        if chunk:
            leftover += chunk
            if b'REPL_READY' in leftover:
                idx = leftover.index(b'REPL_READY') + len(b'REPL_READY')
                leftover = leftover[idx:]
                print("[+] Got REPL_READY", flush=True)
                break
    except socket.timeout:
        continue
else:
    print("FAIL: Timed out waiting for REPL_READY")
    sys.exit(1)

passes = 0
fails = 0


def test(label, cmd, expect):
    global passes, fails, leftover
    print(f"[>] {label}: sending {cmd!r}", flush=True)
    s.sendall(cmd.encode() + b'\n')
    resp, leftover = read_eot(s, leftover)
    if resp is None:
        print(f"  FAIL: timeout", flush=True)
        fails += 1
        return
    print(f"  got={resp!r}  expected={expect!r}", flush=True)
    if resp == expect:
        print(f"  PASS", flush=True)
        passes += 1
    else:
        print(f"  FAIL", flush=True)
        fails += 1


# Test 1: code calls SerSend — loop must NOT add a second EOT
test("SerSend",    'SerSend("hello");',  b'hello')

# Test 2: code calls SerSendOk — loop must NOT add a second EOT
test("SerSendOk",  'SerSendOk();',       b'OK')

# Test 3: code calls SerSendErr — loop must NOT add a second EOT
test("SerSendErr", 'SerSendErr("bad");', b'ERR:bad')

# Test 4: code sends nothing — loop MUST send fallback OK
test("fallback OK", 'I64 x=1+1;',        b'OK')

print(f"\n{'PASS' if fails == 0 else 'FAIL'}: {passes}/{passes+fails} tests passed")

print("[+] Sending EXIT...", flush=True)
s.sendall(b'EXIT\n')
s.close()
sys.exit(0 if fails == 0 else 1)
