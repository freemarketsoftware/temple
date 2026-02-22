#!/bin/bash
# Loads SerProto.HC (which includes Uart.HC), then runs all Phase 2 tests.
# SerSendInt is dropped — all responses are strings.
#
# Lessons from Phase 1/2:
#  - Always #include SerProto.HC — it pulls in Uart.HC and is self-contained
#  - \n in REPL strings causes LexExcept:0x0A06 — use UartPutChar(10) for newline
#
# Usage:
#   Terminal 1: python3 serial/test_serproto.py   (connect first, holds socket)
#   Terminal 2: ./serial/run_serproto_tests.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEND="$SCRIPT_DIR/sendtext.sh"

echo "[1/4] Loading SerProto.HC (includes Uart.HC)..."
"$SEND" '#include "C:/Home/SerProto.HC"'
sleep 2

echo "[2/4] Sending READY signal..."
"$SEND" 'UartPrint("READY");UartPutChar(10);'

echo "[3/4] Running TX tests (SerSend, SerSendOk, SerSendErr)..."
"$SEND" 'SerSend("hello");SerSendOk();SerSendErr("oops");'

echo "[4/4] Running RX test (SerRecvLine)..."
"$SEND" 'UartPrint("READY");UartPutChar(10);U8 buf[64];SerRecvLine(buf,64);SerSend(buf);'

echo "Done."
