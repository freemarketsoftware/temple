#!/bin/bash
# Write SerReplPrint.HC to TempleOS using Ed, then start the REPL loop.
# Purpose: validate serial receive pipeline by printing received commands
# to the TempleOS console instead of executing them.
# Run a verify script in parallel when ready to test.
#
# Note: includes SerProto.HC (which includes Uart.HC) — self-contained.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEND="$SCRIPT_DIR/sendtext.sh"
MON="/tmp/qmon.sock"

echo "[0] Close any open Ed..."
echo "sendkey esc" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 2

echo "[1] Open Ed for SerReplPrint.HC..."
"$SEND" 'Ed("C:/Home/SerReplPrint.HC");'
sleep 5

echo "[2] Type file content..."
"$SEND" '#include "C:/Home/SerProto.HC"'
"$SEND" 'U0 SerReplPrint(){U8 buf[256];UartPrint("REPL_READY\n");while(1){SerRecvLine(buf,256);if(\!StrCmp(buf,"EXIT"))break;"CMD: %s\n",buf;SerSendOk();}}'
"$SEND" 'SerReplPrint;'

echo "[3] Save with ESC..."
echo "sendkey esc" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 3

echo "[3b] Save VM snapshot so file survives crashes..."
echo "savevm snap1" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 2

echo "[4] Include SerReplPrint.HC (starts REPL loop)..."
"$SEND" '#include "C:/Home/SerReplPrint.HC"'

echo "[5] Done — REPL loop running. Run verify script when ready to test."
