#!/bin/bash
# Write minimal SerRepl.HC (no FileWrite/ExeFile) to isolate compile issues.
# Purpose: confirm REPL_READY is sent and basic loop works.
# Run verify_serrepl_min.py in parallel before running this.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEND="$SCRIPT_DIR/sendtext.sh"
MON="/tmp/qmon.sock"

echo "[0] Close any open Ed..."
echo "sendkey esc" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 2

echo "[1] Open Ed for SerRepl.HC..."
"$SEND" 'Ed("C:/Home/SerRepl.HC");'
sleep 5

echo "[2] Type file content (minimal — no exec)..."
"$SEND" '#include "C:/Home/SerProto.HC"'
"$SEND" 'U0 SerRepl(){U8 buf[256];UartPrint("REPL_READY");UartPutChar(10);while(1){SerRecvLine(buf,256);if(\!StrCmp(buf,"EXIT"))break;SerSendOk();}}'
"$SEND" 'SerRepl;'

echo "[3] Save with ESC..."
echo "sendkey esc" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 3

echo "[4] Start REPL..."
"$SEND" '#include "C:/Home/SerRepl.HC"'

echo "[5] Done — check Python output for REPL_READY."
