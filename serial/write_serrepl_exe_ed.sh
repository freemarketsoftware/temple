#!/bin/bash
# Write SerReplExe.HC to TempleOS using Ed, then start the REPL loop.
# Workaround for undefined ExeStr: writes received command to _r.HC,
# executes it with ExeFile, then deletes it.
# Self-contained — includes SerProto.HC (which includes Uart.HC).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEND="$SCRIPT_DIR/sendtext.sh"
MON="/tmp/qmon.sock"

echo "[0] Close any open Ed..."
echo "sendkey esc" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 2

echo "[1] Open Ed for SerReplExe.HC..."
"$SEND" 'Ed("C:/Home/SerReplExe.HC");'
sleep 5

echo "[2] Type file content..."
"$SEND" '#include "C:/Home/SerProto.HC"'
"$SEND" 'U0 SerReplExe(){U8 buf[256];UartPrint("REPL_READY\n");while(1){SerRecvLine(buf,256);if(\!StrCmp(buf,"EXIT"))break;FileWrite("C:/Home/_r.HC",buf,StrLen(buf));ExeFile("C:/Home/_r.HC");Del("C:/Home/_r.HC");SerSendOk();}}'
"$SEND" 'SerReplExe;'

echo "[3] Save with ESC..."
echo "sendkey esc" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 3

echo "[3b] Save VM snapshot..."
echo "savevm snap1" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 2

echo "[4] Include SerReplExe.HC (starts REPL loop)..."
"$SEND" '#include "C:/Home/SerReplExe.HC"'

echo "[5] Done — REPL loop running. Run verify script when ready to test."
