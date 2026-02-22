#!/bin/bash
# Write SerRepl.HC to TempleOS using Ed, then start the REPL loop.
# Run verify_serrepl.py in parallel before running this.
#
# Design: Eval(buf) + g_replied flag prevents double-EOT.
# SerSend sets g_replied=1; loop sends SerSendOk() only if g_replied==0.
#
# Long lines are split to avoid sendkey character drop corruption.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEND="$SCRIPT_DIR/sendtext.sh"
MON="/tmp/qmon.sock"

echo "[0] Close any open Ed..."
echo "sendkey esc" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 2

echo "[1] Open Ed for SerRepl.HC..."
"$SEND" 'Ed("C:/Home/SerRepl.HC");'
sleep 5

echo "[2] Type file content..."
"$SEND" 'U8 g_replied=0;'
"$SEND" 'U0 SerSend(U8 *s){UartPrint(s);UartPutChar(4);g_replied=1;}'
"$SEND" 'U0 SerSendOk(){SerSend("OK");}'
"$SEND" 'U0 SerSendErr(U8 *s){UartPrint("ERR:");SerSend(s);}'
"$SEND" 'U0 SerRecvLine(U8 *buf,I64 max){'
"$SEND" 'I64 i=0;U8 ch;'
"$SEND" 'while(i<max-1){'
"$SEND" 'ch=UartGetChar();'
"$SEND" 'if(ch==10)break;'
"$SEND" 'buf[i]=ch;i++;'
"$SEND" '}'
"$SEND" 'buf[i]=0;'
"$SEND" '}'
"$SEND" 'U0 SerRepl(){'
"$SEND" 'U8 buf[256];'
"$SEND" 'UartPrint("REPL_READY\n");'
"$SEND" 'while(1){'
"$SEND" 'g_replied=0;'
"$SEND" 'SerRecvLine(buf,256);'
"$SEND" 'if(\!StrCmp(buf,"EXIT"))break;'
"$SEND" 'ExeStr(buf);'
"$SEND" 'if(\!g_replied)SerSendOk();'
"$SEND" '}'
"$SEND" '}'
"$SEND" 'SerRepl;'

echo "[3] Save with ESC..."
echo "sendkey esc" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 3

echo "[4] Include SerRepl.HC (starts REPL)..."
"$SEND" '#include "C:/Home/SerRepl.HC"'

echo "[5] Done — REPL loop running, check Python output."
