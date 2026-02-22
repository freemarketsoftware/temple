#!/bin/bash
# Sends Test3 into TempleOS as a SINGLE LINE so HolyC compiles it as a unit.
# Multi-line entry does not work — TempleOS compiles each line immediately.
# Uses UartGetChar() (blocking) + UartPrint("ECHO:") + UartPutChar(10) for newline.
# Run AFTER test3_auto.py is connected and holding the socket open.
#
# Usage: ./serial/send_test3.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEND="$SCRIPT_DIR/sendtext.sh"

echo "Sending #include..."
"$SEND" '#include "C:/Home/Uart.HC"'
sleep 2   # wait for compile

echo "Defining Test3 as one-liner (sends READY before blocking on RX)..."
"$SEND" 'U0 Test3(){I64 i;U8 ch;UartInit(UART_DIV_115200);UartPrint("READY\n");for(i=0;i<5;i++){ch=UartGetChar();UartPrint("ECHO:");UartPutChar(ch);UartPutChar(10);}}'
sleep 1

echo "Calling Test3 — TempleOS will now block on UartGetChar waiting for HELLO..."
"$SEND" 'Test3;'

echo "Done — test3_auto.py will send HELLO after SEND_DELAY."
