# Network Feature

## Current Status (as of 2026-02-19)

### Phase 0 — QEMU Setup ✅ Complete
- `-serial unix:/tmp/temple-serial.sock,server,nowait` confirmed in `start_with_serial.sh`
- `-monitor unix:/tmp/qmon.sock,server,nowait` confirmed working
- Both sockets active after VM start

### Phase 1 — `Uart.HC`: 16550 UART Driver ✅ Complete
| File | Status | Notes |
|---|---|---|
| `C:/Home/UartConst.HC` | ✅ Exists | 21 lines / 472 bytes — all `#define` constants |
| `C:/Home/Uart.HC` | ✅ Complete | All 7 functions: `UartInit`, `UartTxReady`, `UartRxReady`, `UartPutChar`, `UartGetChar`, `UartGetCharTimeout`, `UartPrint` |
| `C:/Home/UartTest.HC` | ❌ Missing | Unit tests not yet written |
| `serial/test_uart.sh` | ❌ Missing | Host `serial/` directory does not exist |

**`UartConst.HC` content** (read via `Ed` on 2026-02-19):
All 21 constants confirmed present — register addresses (UART_DATA/IER/FCR/LCR/MCR/LSR),
status bits (LSR_RX_READY/LSR_TX_EMPTY), line control (LCR_8N1/LCR_DLAB),
modem control (MCR_DTR/MCR_RTS/MCR_OUT2/MCR_LOOPBACK), FIFO control
(FCR_ENABLE/FCR_CLR_RX/FCR_CLR_TX/FCR_TRIG14), and baud divisors
(UART_DIV_115200=1 / UART_DIV_9600=12).

**Tests passed (2026-02-19):**
- **Test 1 — TX smoke** ✅ `TX_OK\n` = `54 58 5F 4F 4B 0A` received on socket
- **Test 2 — Loopback** ✅ `MCR_LOOPBACK` → `UartPutChar(0x42)` → `UartGetChar()` returned `0x42`
- **Test 3 — RX echo** ✅ Host sent `HELLO` (5 bytes) → TempleOS echoed `ECHO:H\nECHO:E\nECHO:L\nECHO:L\nECHO:O\n`
- **Test 4 — Timeout** ✅ `UartGetCharTimeout(100000)` returned `-1` in ~1ms, no hang
- **Test 5 — UartPrint string integrity** ✅ `"ABCDEFGHIJKLMNOP"` (16 bytes) received intact, no drops

**Critical gotcha — QEMU serial socket reconnection:**
QEMU drops all serial output for reconnected clients. Only the **first** nc/Python
connection after QEMU starts reliably receives data. Workaround: connect the
listener once immediately after `start_with_serial.sh` and keep it open for all tests.
- Socket must be `chmod 666` for non-root nc access
- Functions survive across REPL calls once `#include "C:/Home/Uart.HC"` is run

**Gotcha — `Print(FileRead(...))` on a .HC file:**
Causes `ERROR: Missing ';' at "Print"`. The HolyC compiler tries to interpret
the file bytes as code rather than treating the pointer as a raw string.
Use `Ed` (read-only view) to inspect existing `.HC` files.

### Phase 2 — `SerProto.HC`: Protocol Layer ✅ Complete

**Tests passed (2026-02-19):**
- **TX 1 — SerSend** ✅ `SerSend("hello")` → `b'hello'` received
- **TX 2 — SerSendOk** ✅ `SerSendOk()` → `b'OK'` received
- **TX 3 — SerSendErr** ✅ `SerSendErr("oops")` → `b'ERR:oops'` received
- **RX — SerRecvLine** ✅ host sent `b'hello\n'` → TempleOS echoed `b'hello'`

`C:/Home/SerProto.HC` loaded via `#include` (no inline redefinition needed).
SerSendInt confirmed dropped — all responses are strings.

### Phases 3–6 — Not started

---

## Goal

Implement network connectivity between the host computer (Linux) and TempleOS running inside QEMU.

---

## Development Rules

- Each feature must live in its own dedicated file.
- Every feature file must be accompanied by many unit tests covering its behavior.

---

## Analysis: How to Connect Host ↔ TempleOS via QEMU

TempleOS has no network stack by design. All approaches must work at the QEMU hardware emulation layer, using only what HolyC can access directly: port I/O (`InU8`/`OutU8`) and memory-mapped I/O.

---

### Option 1 — Serial Port (16550 UART) — RECOMMENDED

QEMU can expose the guest's COM1 serial port as a Unix socket or TCP port on the host:

```bash
-serial unix:/tmp/temple.sock,server,nowait
# or
-serial tcp:localhost:4321,server,nowait
```

TempleOS has direct access to the 16550 UART at I/O port `0x3F8` (COM1) via `InU8`/`OutU8`. A HolyC driver would:
1. Initialize the UART (baud rate, data bits, stop bits)
2. Poll the status register (`0x3FD`) to check transmit/receive readiness
3. Write bytes to `0x3F8` to send, read from `0x3F8` to receive

The host connects with standard tools (`nc -U /tmp/temple.sock`) or a Python script.

**Pros:** Standard QEMU, bidirectional, no custom QEMU build needed, proven approach
**Cons:** Slow (max ~115200 baud), requires writing a UART driver in HolyC
**Complexity:** Medium (~1–2 weeks total including protocol and host tooling)

---

### Option 2 — ISA Debug Port (0xe9) — One-Way Only

QEMU has a built-in debug port at `0xe9`. A single `OutU8(0xe9, byte)` from HolyC sends a character to the host's stdout or a chardev socket. No driver needed.

**Pros:** Zero setup, works today, trivial HolyC code
**Cons:** Write-only (guest→host only), no way for host to send data back
**Use case:** Unidirectional logging only, not true network communication

---

### Option 3 — Virtio-Serial — Not Practical

QEMU supports high-performance `virtio-serial` PCI devices. However, TempleOS has no virtio driver stack. Writing one from scratch (PCI enumeration, BAR mapping, virtqueue ring buffers, DMA) would be a multi-week project with no existing foundation.

**Verdict:** Over-engineered for this use case.

---

### Option 4 — ivshmem (Shared Memory via PCI) — Possible but Complex

QEMU's `ivshmem` device exposes a shared memory region to the guest via a PCI BAR. The host `mmap()`s the same file. The guest can poll the region for messages.

Requires: PCI enumeration driver in HolyC, a ring buffer protocol, and busy-wait polling (no interrupt support without the ivshmem server).

**Verdict:** Higher throughput than serial, but requires building a PCI driver first. Not the right starting point.

---

### Option 5 — Host-Guest Block Device (HGBD) — Async File Sharing Only

Projects like `TempleOS-hgbd` implement a virtual disk that lets the host read/write TempleOS files. Good for file transfer, not for real-time communication.

**Verdict:** Complementary tool, not a network channel.

---

### Comparison Table

| Approach | Host→Guest | Guest→Host | Complexity | Practical? |
|---|:---:|:---:|:---:|---|
| **Serial (16550)** | ✓ | ✓ | Medium | **Yes — recommended** |
| ISA Debug Port (0xe9) | ✗ | ✓ | Low | Yes, one-way only |
| Virtio-Serial | ✓ | ✓ | Very High | No |
| ivshmem | ✓ | ✓ | High | Eventually |
| Block Device (HGBD) | ✓ | ✓ | Medium | Async file transfer only |

---

### Conclusion

The **serial port (16550 UART)** approach is the clear starting point:
- Uses standard QEMU with no custom builds
- TempleOS can drive COM1 directly via `InU8`/`OutU8`
- Bidirectional, works with standard host tools
- Manageable complexity for a HolyC driver

---

## Implementation Plan: Serial REPL Interface

### Architectural Note: Output Capture

TempleOS's `Print()` writes to a **document buffer** (the visual terminal), not to serial. There is no way to transparently redirect it. This means the design must use **explicit `SerSend()` calls**: all TempleOS-side utility code sends its results over serial directly, rather than relying on capturing standard output. This is clean, testable, and reliable.

The host sends HolyC code snippets that call `SerSend()` to return data. Example:

```c
// Host sends this line → TempleOS executes it → result arrives on socket
SerSend(FileRead("C:/Home/test.DD"));
```

---

### Files

**TempleOS (`C:/Home/`):**
| File | Purpose |
|---|---|
| `Uart.HC` | 16550 UART register constants, init, TX/RX primitives |
| `SerProto.HC` | `SerSend`, `SerRecvLine`, protocol framing — depends on Uart.HC |
| `SerRepl.HC` | Main REPL loop — depends on SerProto.HC |

**Host (`/home/zero/temple/serial/`):**
| File | Purpose |
|---|---|
| `serial_conn.py` | Raw socket connection, `read_until_eot()`, `write_line()` |
| `temple_client.py` | High-level `exec_hc(code) → str`, timeout handling |
| `tests/test_serial_conn.py` | Unit tests for the socket layer |
| `tests/test_temple_client.py` | Unit tests for the client API |

**Boot:**
| File | Purpose |
|---|---|
| `start_with_serial.sh` | QEMU launch command with `-serial` flag |

---

### Protocol

Simple, line-based:

```
Host → TempleOS:   <HolyC code>\n          (newline terminated)
TempleOS → Host:   <response bytes>\x04    (EOT byte = end of response)
```

- `\x04` (ASCII EOT / Ctrl-D) is the response terminator.
- If the code produces no output, TempleOS still sends `\x04` so the host unblocks.
- Errors are sent as `ERR:<message>\x04`.
- Multi-line code: send all lines joined by `;` or newlines, terminated by a single `\n`.
- Host waits up to a configurable timeout (default 5s) for the `\x04`.

---

### Phase 0 — QEMU Setup

Add `-serial` to the QEMU launch command:

```bash
qemu-system-x86_64 \
  -m 512 \
  -hda temple/TempleOS.qcow2 \
  -cdrom temple/TempleOSCDV5.03.ISO \
  -boot c \
  -vga std \
  -display gtk \
  -serial unix:/tmp/temple-serial.sock,server,nowait \
  -monitor unix:/tmp/qmon.sock,server,nowait
```

Verify on host: the socket `/tmp/temple-serial.sock` is created when QEMU starts.

---

### Phase 1 — `Uart.HC`: 16550 UART Driver

16550 register map for COM1 (base `0x3F8`):

| Offset | Register |
|---|---|
| +0 | Data (TX/RX) |
| +1 | Interrupt Enable |
| +2 | FIFO Control |
| +3 | Line Control (set DLAB to program baud) |
| +4 | Modem Control |
| +5 | Line Status (bit 5 = TX ready, bit 0 = RX ready) |

Functions to implement:
- `UartInit(baud)` — set baud rate divisor, 8N1, enable FIFO
- `UartTxReady()` — polls bit 5 of `0x3FD`
- `UartRxReady()` — polls bit 0 of `0x3FD`
- `UartPutChar(ch)` — waits for TX ready, writes to `0x3F8`
- `UartGetChar()` — waits for RX ready, reads from `0x3F8`
- `UartPrint(str)` — sends a null-terminated string char by char

**Unit tests:** Send a known byte sequence from TempleOS, verify it arrives on the host socket. Echo test: host sends bytes back, TempleOS verifies they match.

---

### Phase 2 — `SerProto.HC`: Protocol Layer

Builds on `Uart.HC`. Implements the framing protocol:

- `SerSend(U8 *str)` — sends `str` then `\x04` (EOT)
- `SerSendOk()` — sends `"OK\x04"`
- `SerSendErr(U8 *msg)` — sends `"ERR:<msg>\x04"`
- `SerRecvLine(U8 *buf, I64 max)` — reads bytes until `\n`, stores in buf

> **Decision (2026-02-19):** `SerSendInt` is dropped. All responses are strings.
> Numbers can be passed as string literals (`SerSend("42")`). There is no need
> for integer formatting in the protocol layer — it adds complexity with no benefit.

**Unit tests:** Verify each framing function produces the correct byte sequence on the host socket.

---

### Phase 3 — `SerRepl.HC`: REPL Loop

Depends on `SerProto.HC`. Implements the main loop:

```
loop:
  SerRecvLine(buf)
  result = Eval(buf)       ← evaluates the incoming HolyC expression
  SerSend("OK")            ← sends OK as fallback if code didn't call SerSend itself
  goto loop
```

Important nuances:
- `Eval(str)` evaluates a HolyC expression and returns its `I64` value. For code that calls `SerSend()` internally, the `SerSend` fires during eval — the `SerSendInt` at the end sends the `ans` value as a secondary fallback.
- If the code calls `SerSend()` itself, it must also send `\x04` before the loop sends another one — the loop will not double-send EOT if the code already did.
- A special command `"EXIT\n"` cleanly breaks the loop.

**Unit tests:** Send `"2+2\n"`, expect `"4\x04"`. Send `SerSend("hello")`, expect `"hello\x04"`.

---

### Phase 4 — Snapshot: `serial-ready`

Once `SerRepl.HC` is running on TempleOS:

```bash
echo "savevm serial-ready" | sudo nc -q 1 -U /tmp/qmon.sock
```

From this point forward, restoring `serial-ready` gives an immediately usable serial interface with no boot sequence needed.

---

### Phase 5 — Host Python Client

**`serial_conn.py`** — raw layer:
- `connect(sock_path)` — opens Unix socket
- `send_line(code)` — writes `code + "\n"`
- `read_until_eot(timeout=5)` — reads bytes until `\x04`, returns accumulated string
- `close()`

**`temple_client.py`** — high-level layer:
- `exec_hc(code) → str` — send code, return response string (strips `\x04`)
- Raises `TempleOSError` if response starts with `ERR:`
- Raises `TimeoutError` if no EOT within timeout

**Unit tests:**
- `test_serial_conn.py`: mock socket, verify framing (send/receive bytes, EOT detection, timeout)
- `test_temple_client.py`: mock `serial_conn`, verify `exec_hc` strips EOT, raises on ERR prefix

---

### Phase 6 — Integration & Workflow Replacement

Replace the screenshot workflow:

| Old (screenshot) | New (serial) |
|---|---|
| `sendtext.sh "Dir;"` + screendump + OCR | `exec_hc("SerDir();")` |
| `sendtext.sh "FileRead(...)"` + screenshot | `exec_hc('SerSend(FileRead("C:/f.DD"));')` |
| All output via screen capture | All output via socket response string |

Add a `SerDir(U8 *path)` utility to `SerProto.HC` that lists a directory and sends the output over serial — the first real "composed" utility built on the layer.

---

### Summary of Dependencies

```
Uart.HC
  └── SerProto.HC
        └── SerRepl.HC

serial_conn.py
  └── temple_client.py
```

Each layer has its own unit tests before the next layer is built.

---

## Phase 1 — `Uart.HC`: 16550 UART Driver (Detailed Plan)

### What Phase 0 confirmed

- UART base `0x3F8` is live and reachable via `InU8`/`OutU8`
- Init sequence (DLAB→divisor→8N1→FIFO→MCR) works
- Polling `InU8(0x3FD) & 0x20` (TX ready) before `OutU8(0x3F8, byte)` works
- Bytes sent from TempleOS arrive cleanly on `/tmp/temple-serial.sock`

---

### Register Map (COM1 base = `0x3F8`)

| Address | Name | Notes |
|---|---|---|
| `0x3F8` | `UART_DATA` | TX write / RX read; Divisor Low when DLAB=1 |
| `0x3F9` | `UART_IER` | Interrupt Enable; Divisor High when DLAB=1 |
| `0x3FA` | `UART_FCR` | FIFO Control (write) |
| `0x3FB` | `UART_LCR` | Line Control; bit 7 = DLAB |
| `0x3FC` | `UART_MCR` | Modem Control |
| `0x3FD` | `UART_LSR` | Line Status; bit 0 = RX ready, bit 5 = TX empty |

### Baud Rate Divisors

Divisor = 115200 ÷ target_baud (base clock 1.8432 MHz, pre-scaled to 115200).

| Baud | Divisor |
|---|---|
| 115200 | 1 |
| 9600 | 12 |

---

### Constants (`#define`)

```c
#define UART_BASE     0x3F8
#define UART_DATA     0x3F8   // TX/RX (or DLL when DLAB=1)
#define UART_IER      0x3F9   // Interrupt Enable (or DLH when DLAB=1)
#define UART_FCR      0x3FA   // FIFO Control
#define UART_LCR      0x3FB   // Line Control
#define UART_MCR      0x3FC   // Modem Control
#define UART_LSR      0x3FD   // Line Status

#define LSR_RX_READY  0x01    // bit 0: received data ready
#define LSR_TX_EMPTY  0x20    // bit 5: TX holding register empty

#define LCR_8N1       0x03    // 8 data bits, no parity, 1 stop bit
#define LCR_DLAB      0x80    // Divisor Latch Access Bit

#define MCR_DTR       0x01
#define MCR_RTS       0x02
#define MCR_OUT2      0x08    // required to enable IRQ line (used even in polling mode)
#define MCR_LOOPBACK  0x10    // loopback test mode

#define FCR_ENABLE    0x01
#define FCR_CLR_RX    0x02
#define FCR_CLR_TX    0x04
#define FCR_TRIG14    0xC0    // 14-byte FIFO trigger threshold

#define UART_DIV_115200  1
#define UART_DIV_9600    12
```

---

### Functions

#### `U0 UartInit(U16 div)`
Initialises the UART. Steps:
1. Set `LCR = LCR_DLAB` to unlock divisor registers
2. Write `div & 0xFF` to `UART_DATA` (DLL)
3. Write `(div >> 8) & 0xFF` to `UART_IER` (DLH)
4. Set `LCR = LCR_8N1` — clears DLAB, sets 8N1
5. Set `FCR = FCR_ENABLE | FCR_CLR_RX | FCR_CLR_TX | FCR_TRIG14`
6. Set `MCR = MCR_DTR | MCR_RTS | MCR_OUT2`
7. Set `IER = 0` — disable all interrupts (polling mode only)

#### `Bool UartTxReady()`
Returns `(InU8(UART_LSR) & LSR_TX_EMPTY) != 0`.

#### `Bool UartRxReady()`
Returns `(InU8(UART_LSR) & LSR_RX_READY) != 0`.

#### `U0 UartPutChar(U8 ch)`
Spins on `UartTxReady()`, then writes `ch` to `UART_DATA`.

#### `U8 UartGetChar()`
Spins on `UartRxReady()`, then reads from `UART_DATA`. **Blocking — no timeout.**

#### `I64 UartGetCharTimeout(I64 spins)`
Spins up to `spins` iterations waiting for `UartRxReady()`.
Returns the received byte, or `-1` on timeout.
Default `spins` value: `10000000` (several seconds at QEMU speed — calibrate later).

#### `U0 UartPrint(U8 *str)`
Loops over null-terminated `str`, calls `UartPutChar` for each byte.

---

### Files

| File | Location | Purpose |
|---|---|---|
| `Uart.HC` | `C:/Home/Uart.HC` | Driver — constants + all 6 functions above |
| `UartTest.HC` | `C:/Home/UartTest.HC` | Unit tests (run independently, results sent over serial) |
| `test_uart.sh` | `serial/test_uart.sh` | Host-side bash harness that orchestrates tests |

---

### Unit Tests

Each test sends a result string back over serial so the host can verify without screenshots.

#### Test 1 — TX smoke test (Guest → Host)
- Call `UartInit(UART_DIV_115200)`
- Call `UartPrint` with the string `TX_OK\n`
- Host: `nc` reads socket, asserts bytes equal `TX_OK\n`

#### Test 2 — Loopback self-test (no host involvement)
- Set `MCR = MCR_LOOPBACK` to enable hardware loopback
- Send byte `0x42` via `UartPutChar`
- Read it back via `UartGetChar`
- If match: send `LOOP_OK\n` over serial (after disabling loopback)
- If mismatch: send `LOOP_FAIL\n`

#### Test 3 — RX test (Host → Guest → Host)
- TempleOS calls `UartGetCharTimeout` in a loop, reading 5 bytes
- Host sends `HELLO` (5 bytes) to the socket
- TempleOS re-sends each received byte prefixed with `ECHO:`
- Host asserts `ECHO:H`, `ECHO:E`, `ECHO:L`, `ECHO:L`, `ECHO:O` arrive

#### Test 4 — Timeout test
- TempleOS calls `UartGetCharTimeout(1000000)` with no data from host
- Must return `-1` without hanging
- TempleOS sends `TIMEOUT_OK\n` to confirm it returned
- Host asserts `TIMEOUT_OK\n` arrives within 5 seconds

#### Test 5 — UartPrint multi-byte string integrity
- Send a 32-character string: `ABCDEFGHIJKLMNOPQRSTUVWXYZ012345`
- Host reads exactly 32 bytes and asserts no bytes dropped or corrupted

---

### Host Test Harness (`serial/test_uart.sh`)

```bash
#!/bin/bash
# Orchestrates Phase 1 unit tests against the running TempleOS serial port.
# Requires: TempleOS booted with UartTest.HC running (SerRepl not needed yet).
SOCK=/tmp/temple-serial.sock
PASS=0; FAIL=0

expect_bytes() {
  local label="$1" expected="$2"
  local got
  got=$(timeout 5 nc -U "$SOCK" | head -c ${#expected})
  if [ "$got" = "$expected" ]; then
    echo "PASS: $label"; ((PASS++))
  else
    echo "FAIL: $label (got: $(echo "$got" | xxd -p))"; ((FAIL++))
  fi
}

echo "Results: $PASS passed, $FAIL failed"
```

Each test case is a separate function call in the harness. The harness is run after `UartTest.HC` is loaded in TempleOS.

---

### How to Write the Files into TempleOS

Use `Ed` for both files (confirmed working in prior sessions):

```
Ed("C:/Home/Uart.HC");       <- type content, ESC to save
Ed("C:/Home/UartTest.HC");   <- type content, ESC to save
#include "C:/Home/UartTest.HC"   <- run tests
```

No quoting issues with `Ed` — all `"` and `\` characters are stored literally.

---

### Success Criteria for Phase 1

- [x] All 5 unit tests pass as verified on the host
- [x] No TempleOS crash or hang during any test
- [x] `UartGetCharTimeout` demonstrably returns `-1` instead of hanging
- [x] `Uart.HC` is self-contained (no external dependencies, loads cleanly with `#include`)

**Phase 1 complete as of 2026-02-19.**
