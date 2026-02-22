# Phase 1 — Test 3: RX Test (Host → Guest → Host) ✅ PASSED 2026-02-19

## What This Tests

`UartGetCharTimeout` and `UartRxReady` — the receive path.
This is the **only untested direction**: host sending bytes into the serial socket,
TempleOS reading them, and echoing them back.

TX path (TempleOS → host) is proven by Tests 1, 2, 4, 5.
RX path (host → TempleOS) has never been exercised.

---

## Prerequisites

- QEMU running with `-serial unix:/tmp/temple-serial.sock,server,nowait`
- `Uart.HC` loaded in TempleOS (via `#include "C:/Home/Uart.HC"`)
- **Critical:** the serial socket listener must be connected *before* sending any data.
  QEMU drops data for clients that connect after the VM starts.

---

## TempleOS Side — HolyC Code to Enter

Type (or paste via `sendtext.sh`) into the TempleOS REPL:

```c
#include "C:/Home/Uart.HC"
U0 Test3() {
  U8 ch;
  I64 i;
  U8 msg[7];
  UartInit(UART_DIV_115200);
  for (i = 0; i < 5; i++) {
    ch = UartGetCharTimeout(50000000);
    if (ch == -1) {
      UartPrint("ECHO:TIMEOUT\n");
    } else {
      msg[0]='E'; msg[1]='C'; msg[2]='H'; msg[3]='O'; msg[4]=':';
      msg[5]=ch; msg[6]='\n'; msg[7]=0;
      UartPrint(msg);
    }
  }
}
Test3;
```

---

## Host Side — What to Do

### Step 1 — Open the listener (keep it open)

```bash
# Terminal A — stays open for the whole test
sudo nc -U /tmp/temple-serial.sock
```

Or use Python if nc has issues:

```python
import socket, time
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('/tmp/temple-serial.sock')
# send after TempleOS starts Test3
time.sleep(2)
s.sendall(b'HELLO')
data = s.recv(64)
print(repr(data))
```

### Step 2 — Trigger Test3 in TempleOS

Enter the HolyC code above in the TempleOS REPL.

### Step 3 — Send `HELLO` from host

In a second terminal (while `nc` in Terminal A is still connected):

```bash
# Terminal B — send 5 bytes to the socket
printf 'HELLO' | sudo nc -U /tmp/temple-serial.sock
```

**Note:** The above opens a *second* connection. If QEMU only delivers data on the
first connection, use the Python approach instead (single persistent connection,
send and receive on the same socket).

### Step 4 — Assert expected output

TempleOS should send back over serial:

```
ECHO:H
ECHO:E
ECHO:L
ECHO:L
ECHO:O
```

Hex: `45 43 48 4F 3A 48 0A  45 43 48 4F 3A 45 0A  ...`

---

## Known Risk: QEMU Single-Connection Gotcha

QEMU serial sockets only reliably deliver data to the **first** connected client.
A second `nc` that connects after QEMU started may not receive — or send — anything.

**Safe approach:** use a single Python script that:
1. Connects to the socket
2. Waits for Test3 to start (small sleep)
3. Sends `HELLO` on the same connection
4. Reads the 5 `ECHO:X\n` lines back

```python
#!/usr/bin/env python3
import socket, time

SOCK = '/tmp/temple-serial.sock'

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(SOCK)
s.settimeout(10)

print("Connected. Waiting for TempleOS to enter Test3...")
time.sleep(3)  # adjust: run Test3 in TempleOS before this sleep ends

s.sendall(b'HELLO')
print("Sent: HELLO")

buf = b''
while b'ECHO:O' not in buf:
    buf += s.recv(64)

print("Received:", repr(buf))
expected = b'ECHO:H\nECHO:E\nECHO:L\nECHO:L\nECHO:O\n'
if buf == expected:
    print("PASS")
else:
    print("FAIL")
    print("Expected:", repr(expected))
s.close()
```

---

## Success Criteria

- [ ] TempleOS receives all 5 bytes from the host without timeout
- [ ] Each byte echoed back as `ECHO:X\n` in correct order
- [ ] No `ECHO:TIMEOUT` lines appear
- [ ] Host receives all 5 echo lines intact

## Failure Modes to Investigate

| Symptom | Likely Cause |
|---|---|
| All `ECHO:TIMEOUT` | RX path broken — `UartRxReady` never fires, or data not reaching guest |
| First byte ok, rest timeout | FIFO issue or polling loop exits too early |
| `nc` receives nothing | Second-connection QEMU gotcha — use single persistent Python connection |
| TempleOS hangs | `UartGetCharTimeout` spin count too low — increase to `100000000` |

---

## Lessons Learned (from actual run 2026-02-19)

### 1. Multi-line function entry does NOT work
Typing a function line-by-line in the TempleOS REPL fails. Each line is compiled
immediately on Enter. `U0 Test3() {` becomes an empty function, then subsequent
lines run in global scope and fail. **Always put the entire function on one line.**

### 2. sendtext.sh is ~0.25s per key, not 0.05s
Each keystroke requires a `sudo nc` invocation to the QEMU monitor. The real
cost per key is ~0.2s overhead + 0.05s sleep = **~0.25s/char**.
A 136-char one-liner takes ~35 seconds to type. Plan accordingly.

### 3. Uppercase hex in HolyC REPL causes parse errors
`0x0A` in the REPL was lexed as `0x0` (hex 0) + identifier `A6` → error.
**Use decimal literals** (`10` instead of `0x0A`, `58` instead of `0x3A`, etc.)
when typing via sendtext.sh, or use lowercase hex where A-F digits appear.

### 4. Fix: READY handshake decouples timing entirely
TempleOS sends `"READY\n"` after `UartInit` and before entering the RX loop.
Python blocks reading until `READY` arrives, then sends `HELLO` immediately.
This is robust regardless of how long typing takes.
See `serial/test3_auto.py` and updated `serial/send_test3.sh`.

### 5. QEMU reconnected clients CAN send data to the guest
The "first client" gotcha affects OUTPUT (TempleOS→host). INPUT (host→TempleOS)
works fine from reconnected clients — QEMU delivers bytes to the UART FIFO
regardless of client connection history.

---

## Result

```
recv: b'ECHO:H\nECHO:E\nECHO:L\nECHO:L\nECHO:O\n'
```

All 5 bytes received and echoed correctly. `UartGetChar()` and `UartRxReady()`
confirmed working. RX path verified.

---

## Phase 1 Complete. Next: Phase 2 — `SerProto.HC`

Success criteria for Phase 1 (all checked):
- [x] Test 1 — TX smoke
- [x] Test 2 — Loopback
- [x] Test 3 — RX echo
- [x] Test 4 — Timeout
- [x] Test 5 — String integrity
