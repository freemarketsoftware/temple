#!/bin/bash
# Writes C:/Home/SerProto.HC into TempleOS via Ed.
# Ed stores raw keystrokes — no REPL parsing issues with quotes or backslashes.
# Takes ~2 minutes (0.25s/key via sudo nc).
#
# Usage: ./serial/write_serproto.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEND="$SCRIPT_DIR/sendtext.sh"
MON="/tmp/qmon.sock"

send_esc() {
  echo "sendkey esc" | sudo nc -q 1 -U "$MON" > /dev/null 2>&1
  sleep 0.1
}

echo "[1/8] Opening Ed..."
"$SEND" 'Ed("C:/Home/SerProto.HC")'
sleep 1   # wait for Ed to open

echo "[2/8] Writing #include line..."
"$SEND" '#include "C:/Home/Uart.HC"'

echo "[3/8] Writing SerSend..."
"$SEND" 'U0 SerSend(U8 *s){UartPrint(s);UartPutChar(4);}'

echo "[4/8] Writing SerSendOk..."
"$SEND" 'U0 SerSendOk(){UartPrint("OK");UartPutChar(4);}'

echo "[5/8] Writing SerSendErr..."
"$SEND" 'U0 SerSendErr(U8 *s){UartPrint("ERR:");UartPrint(s);UartPutChar(4);}'

echo "[6/8] Writing SerSendInt..."
"$SEND" 'U0 SerSendInt(I64 n){U8 buf[22];I64 i=21;U8 neg=0;buf[21]=0;if(n<0){neg=1;n=-n;}if(n==0){buf[--i]=48;}while(n>0){buf[--i]=48+n%10;n/=10;}if(neg)buf[--i]=45;SerSend(buf+i);}'

echo "[7/8] Writing SerRecvLine..."
"$SEND" 'U0 SerRecvLine(U8 *buf,I64 max){I64 i=0;U8 ch;while(i<max-1){ch=UartGetChar();if(ch==10)break;buf[i]=ch;i++;}buf[i]=0;}'

echo "[8/8] Saving with ESC..."
sleep 0.5
send_esc

echo "Done — C:/Home/SerProto.HC written."
