#!/bin/bash
# Phase 2 — SerRecvLine test
# Run test_recvline.py in parallel before running this.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEND="$SCRIPT_DIR/sendtext.sh"

echo "[1/6] Load Uart.HC..."
"$SEND" '#include "C:/Home/Uart.HC"'
sleep 2

echo "[2/6] Define SerSend..."
"$SEND" 'U0 SerSend(U8 *s){UartPrint(s);UartPutChar(4);}'
sleep 1

echo "[3/6] Define SerRecvLine..."
"$SEND" 'U0 SerRecvLine(U8 *buf,I64 max){I64 i=0;U8 ch;while(i<max-1){ch=UartGetChar();if(ch==10)break;buf[i]=ch;i++;}buf[i]=0;}'
sleep 1

echo "[4/6] Send READY..."
"$SEND" 'UartPrint("READY");UartPutChar(10);'
sleep 1

echo "[5/6] Run SerRecvLine then echo back..."
"$SEND" 'U8 buf[64];SerRecvLine(buf,64);SerSend(buf);'

echo "[6/6] Done — check Python output."
