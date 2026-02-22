#!/bin/bash
# Diagnostic: verify Ed file creation works via sendkey.
#
# Protocol:
#   Python connects first (holds serial socket).
#   This script types into TempleOS, creates TestEdDiag.HC, runs it.
#   Python listens for "EDOK" + EOT to confirm Ed saved the file.
#
# Usage:
#   Terminal 1: python3 serial/test_ed_check.py
#   Terminal 2: ./serial/test_ed_write.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEND="$SCRIPT_DIR/sendtext.sh"
MON="/tmp/qmon.sock"

echo "[1/6] Loading Uart.HC..."
"$SEND" '#include "C:/Home/Uart.HC"'
sleep 2

echo "[2/6] Opening Ed (TestEdDiag.HC)..."
"$SEND" 'Ed("C:/Home/TestEdDiag.HC")'
sleep 5  # Wait for Ed to fully open

echo "[3/6] Typing function into Ed..."
"$SEND" 'U0 EdTest(){UartPrint("EDOK");UartPutChar(4);}'
sleep 2

echo "[4/6] Saving with ESC..."
echo "sendkey esc" | sudo nc -q 1 -U "$MON" > /dev/null 2>&1
sleep 3  # Wait for Ed to close and REPL to return

echo "[5/6] Including TestEdDiag.HC..."
"$SEND" '#include "C:/Home/TestEdDiag.HC"'
sleep 2

echo "[6/6] Calling EdTest..."
"$SEND" 'EdTest;'
echo "Done. Waiting for Python to report result..."
