#!/usr/bin/env python3
"""
Phase 1 — Test 3: RX test (Host -> Guest -> Host)
Tests UartGetCharTimeout / UartRxReady on TempleOS.

Usage:
  1. Boot TempleOS: ./start_with_serial.sh
  2. Run this script FIRST (it connects and holds the socket)
  3. When prompted, type the HolyC in TempleOS (or use sendtext.sh)
  4. Script sends HELLO, reads back ECHO:X lines, reports PASS/FAIL
"""

import socket
import sys
import time

SOCK = '/tmp/temple-serial.sock'
TIMEOUT = 15  # seconds to wait for all 5 echoes
SEND_DELAY = 2  # seconds after prompt before sending HELLO


def connect():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(SOCK)
    except FileNotFoundError:
        print(f"ERROR: Socket not found: {SOCK}")
        print("       Is TempleOS running? Run ./start_with_serial.sh first.")
        sys.exit(1)
    except ConnectionRefusedError:
        print(f"ERROR: Connection refused on {SOCK}")
        sys.exit(1)
    print(f"Connected to {SOCK}")
    return s


def read_lines(s, count, timeout):
    """Read `count` newline-terminated lines from socket within timeout."""
    s.settimeout(timeout)
    lines = []
    buf = b''
    deadline = time.time() + timeout
    while len(lines) < count:
        remaining = deadline - time.time()
        if remaining <= 0:
            raise TimeoutError(f"Timed out after receiving {len(lines)}/{count} lines")
        s.settimeout(remaining)
        try:
            chunk = s.recv(64)
        except socket.timeout:
            raise TimeoutError(f"Timed out after receiving {len(lines)}/{count} lines")
        if not chunk:
            raise ConnectionError("Socket closed by QEMU")
        buf += chunk
        while b'\n' in buf:
            line, buf = buf.split(b'\n', 1)
            lines.append(line)
            print(f"  <- {line!r}")
            if len(lines) >= count:
                break
    return lines


def main():
    s = connect()

    print()
    print("=" * 60)
    print("Now type this in TempleOS (or use sendtext.sh lines below):")
    print()
    print('  #include "C:/Home/Uart.HC"')
    print()
    print("  U0 Test3() {")
    print("    I64 i,ch;")
    print("    U8 msg[8];")
    print("    UartInit(UART_DIV_115200);")
    print("    for (i=0;i<5;i++) {")
    print("      ch=UartGetCharTimeout(50000000);")
    print('      if (ch==-1) { UartPrint("TIMEOUT\\n"); }')
    print('      else { msg[0]=\'E\';msg[1]=\'C\';msg[2]=\'H\';msg[3]=\'O\';')
    print("             msg[4]=':';msg[5]=ch;msg[6]='\\n';msg[7]=0;")
    print("             UartPrint(msg); }")
    print("    }")
    print("  }")
    print("  Test3;")
    print()
    print("sendtext.sh lines (run each in order):")
    print('  ./sendtext.sh "#include \\"C:/Home/Uart.HC\\""')
    print('  ./sendtext.sh "U0 Test3() {"')
    print('  ./sendtext.sh "I64 i,ch; U8 msg[8];"')
    print('  ./sendtext.sh "UartInit(UART_DIV_115200);"')
    print('  ./sendtext.sh "for (i=0;i<5;i++) {"')
    print('  ./sendtext.sh "ch=UartGetCharTimeout(50000000);"')
    print('  ./sendtext.sh "if (ch==-1) { UartPrint(\\\"TIMEOUT\\\\n\\\"); }"')
    print("  # (build msg array and UartPrint — see test3-rx.md for full snippet)")
    print()
    print("=" * 60)
    print()

    input("Press ENTER when Test3 is running in TempleOS and waiting for input...")

    print(f"Waiting {SEND_DELAY}s then sending HELLO...")
    time.sleep(SEND_DELAY)

    payload = b'HELLO'
    s.sendall(payload)
    print(f"  -> sent {payload!r}")

    print(f"Reading 5 echo lines (timeout {TIMEOUT}s)...")
    try:
        lines = read_lines(s, 5, TIMEOUT)
    except TimeoutError as e:
        print(f"\nFAIL: {e}")
        s.close()
        sys.exit(1)
    except ConnectionError as e:
        print(f"\nFAIL: {e}")
        s.close()
        sys.exit(1)

    expected = [b'ECHO:H', b'ECHO:E', b'ECHO:L', b'ECHO:L', b'ECHO:O']

    print()
    passed = True
    for i, (got, exp) in enumerate(zip(lines, expected)):
        if got == exp:
            print(f"  line {i+1}: PASS  {got!r}")
        else:
            print(f"  line {i+1}: FAIL  got={got!r}  expected={exp!r}")
            passed = False

    if any(b'TIMEOUT' in l for l in lines):
        print("\nFAIL: TempleOS reported TIMEOUT — RX path not working")
        passed = False

    print()
    if passed:
        print("RESULT: PASS — Test 3 complete, Phase 1 RX path verified")
    else:
        print("RESULT: FAIL — see lines above")

    s.close()
    sys.exit(0 if passed else 1)


if __name__ == '__main__':
    main()
