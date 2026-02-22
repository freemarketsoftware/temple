#!/bin/bash
# Save current TempleOS state to snap1 and shut down QEMU.
#
# Usage: ./shutdown.sh

MON_SOCK="/tmp/qmon.sock"

if [ ! -S "$MON_SOCK" ]; then
  echo "ERROR: QEMU monitor socket not found ($MON_SOCK). Is QEMU running?"
  exit 1
fi

echo "Saving snapshot snap1..."
echo "savevm snap1" | sudo nc -q 1 -U "$MON_SOCK" > /dev/null

# Wait for save to complete (can take a couple of seconds)
sleep 3

echo "Shutting down QEMU..."
echo "quit" | sudo nc -q 1 -U "$MON_SOCK" > /dev/null

echo "Done. State saved to snap1."
