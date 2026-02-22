#!/bin/bash
# Launch TempleOS in QEMU with serial port exposed as a Unix socket,
# then automatically restore the last saved snapshot (snap1).
#
# Serial socket:  /tmp/temple-serial.sock
# Monitor socket: /tmp/qmon.sock
#
# Usage: ./start_with_serial.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MON_SOCK="/tmp/qmon.sock"
SER_SOCK="/tmp/temple-serial.sock"

# Stop any existing QEMU instance
if [ -S "$MON_SOCK" ]; then
  echo "Stopping existing QEMU instance..."
  echo "quit" | sudo nc -q 1 -U "$MON_SOCK" 2>/dev/null || true
  sleep 2
fi

# Clean up stale sockets
sudo rm -f "$MON_SOCK" "$SER_SOCK"

# Launch QEMU in background
echo "Starting QEMU..."
sudo qemu-system-x86_64 \
  -m 512 \
  -hda "$SCRIPT_DIR/TempleOS.qcow2" \
  -cdrom "$SCRIPT_DIR/TempleOSCDV5.03.ISO" \
  -boot c \
  -vga std \
  -display gtk \
  -serial unix:"$SER_SOCK",server,nowait \
  -monitor unix:"$MON_SOCK",server,nowait &

# Wait for monitor socket to be ready
echo "Waiting for QEMU monitor socket..."
for i in $(seq 1 30); do
  if [ -S "$MON_SOCK" ]; then
    break
  fi
  sleep 0.5
done

if [ ! -S "$MON_SOCK" ]; then
  echo "ERROR: Monitor socket did not appear after 15s"
  exit 1
fi

# Restore saved snapshot
sleep 0.5
echo "Restoring snapshot snap1..."
echo "loadvm snap1" | sudo nc -q 1 -U "$MON_SOCK" > /dev/null

echo "TempleOS ready (C:/Home>)."
echo "  Serial: $SER_SOCK"
echo "  Monitor: $MON_SOCK"
