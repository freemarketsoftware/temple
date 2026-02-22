#!/usr/bin/env python3
"""
Send a file's content to TempleOS over serial.

Protocol:
  TempleOS must be waiting with:
    U8 buf[65536];I64 sz=0;U8 ch;while((ch=UartGetChar())!=4)buf[sz++]=ch;FileWrite("C:/Home/TARGET",buf,sz);

This script sends: file_content + \x04 (EOT terminator)

Usage:
  python3 send_file_to_temple.py <local_file> [delay_seconds]
  e.g.: python3 send_file_to_temple.py SerRepl.HC 5
"""
import socket, sys, time

SOCK = '/tmp/temple-serial.sock'
EOT = b'\x04'

if len(sys.argv) < 2:
    print("Usage: send_file_to_temple.py <local_file> [delay_seconds]")
    sys.exit(1)

filepath = sys.argv[1]
delay = float(sys.argv[2]) if len(sys.argv) > 2 else 3.0

with open(filepath, 'rb') as f:
    content = f.read()

print(f"[+] Sending {filepath!r} ({len(content)} bytes) in {delay}s...")
print(f"    Make sure TempleOS is waiting with UartGetChar loop before this script sends.")
time.sleep(delay)

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(SOCK)
s.sendall(content + EOT)
s.close()

print(f"[+] Sent {len(content)} bytes + EOT.")
print(f"    TempleOS should now have written the file.")
