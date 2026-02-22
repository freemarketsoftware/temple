#!/bin/bash
# Dumps file listing and key file contents from TempleOS via serial.
# Run dump_files.py in parallel to receive output.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEND="$SCRIPT_DIR/sendtext.sh"
MON="/tmp/qmon.sock"

echo "[1] Load Uart.HC..."
"$SEND" '#include "C:/Home/Uart.HC"'
sleep 2

echo "[2] Signal READY..."
"$SEND" 'UartPrint("READY");UartPutChar(10);'
sleep 1

echo "[3] Send Dir listing..."
# WARNING: DirFirst/DirNext are UNVERIFIED — never confirmed working in TempleOS.
# This code was never tested and DirFirst does not appear to exist as a compiled function.
"$SEND" 'U8 *d=DirFirst("C:/Home/*");while(d){UartPrint(d->name);UartPutChar(10);d=DirNext(d);}UartPutChar(4);'
sleep 5

echo "[4] Dump Uart.HC content..."
"$SEND" 'U8 *f;I64 sz;f=FileRead("C:/Home/Uart.HC",&sz);I64 i;for(i=0;i<sz;i++)UartPutChar(f[i]);UartPutChar(4);'
sleep 10

echo "Done."
