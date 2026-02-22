#!/bin/bash
# Write SerProto.HC to TempleOS using Ed, then verify via serial.
# Run verify_serproto.py in parallel before running this.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEND="$SCRIPT_DIR/sendtext.sh"
MON="/tmp/qmon.sock"

echo "[0] Close any open Ed..."
echo "sendkey esc" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 2

echo "[1] Open Ed for SerProto.HC..."
"$SEND" 'Ed("C:/Home/SerProto.HC");'
sleep 5

echo "[2] Type file content..."
"$SEND" '#include "C:/Home/Uart.HC"'
"$SEND" 'U0 SerSend(U8 *s){UartPrint(s);UartPutChar(4);}'
"$SEND" 'U0 SerSendOk(){SerSend("OK");}'
"$SEND" 'U0 SerSendErr(U8 *s){UartPrint("ERR:");SerSend(s);}'
"$SEND" 'U0 SerRecvLine(U8 *buf,I64 max){I64 i=0;U8 ch;while(i<max-1){ch=UartGetChar();if(ch==10)break;buf[i]=ch;i++;}buf[i]=0;}'

echo "[3] Save with ESC..."
echo "sendkey esc" | sudo nc -N -U "$MON" > /dev/null 2>&1
sleep 3

echo "[4] Include SerProto.HC..."
"$SEND" '#include "C:/Home/SerProto.HC"'
sleep 2

echo "[5] Send READY and test SerSend..."
"$SEND" 'UartPrint("READY");UartPutChar(10);'
sleep 1
"$SEND" 'SerSend("PROTO_OK");'

echo "[6] Done — check Python output."
