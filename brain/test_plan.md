# Test Plan

Tracks what has been tested, what is pending, and what is deferred.
Update this file as tests are written and results are confirmed.

## Architecture

Tests use a **TestRunner** pattern:
- Each test is `U0 TestXxx(U8 *out)` — writes TSV rows into a shared buffer
- `TestRunner.HC` includes all safe tests, calls each with section headers, writes one `C:/AI/results/TestResults.txt`
- Python: `sudo python3 serial/run_tests.py` deploys + runs everything + prints results
- **Skip list** (panic the OS — run standalone only): TestIntDivZero, TestMallocEdge2/2b/2c/2d, TestMallocEdge3, Tier 4 tests

---

## Status Key

| Symbol | Meaning |
|--------|---------|
| ✅ | Done — test written, results confirmed |
| 🔄 | In progress |
| ⏳ | Pending — planned, not yet written |
| ⏸ | Standby — deferred, revisit later |

---

## Tier 0 — Foundation

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestMalloc | MAlloc/Free basics | ✅ | |
| TestIntMath | Integer arithmetic | ✅ | |
| TestStrings | StrCpy, StrCmp, StrLen, StrPrint | ✅ | |
| TestFileIO | FileWrite, FileRead, Del | ✅ | |
| TestIntDiv | Integer division, modulo | ✅ | |
| TestIntDivZero | Div-by-zero REPL survival | ✅ | REPL survives via SerReplExe try/catch |
| TestMallocEdge1–6 | MAlloc edge cases | ✅ | Null, 0, OOM, UAF, double-free, reuse |
| TestStrUtil | SUF_TO_UPPER/LOWER, trim, StrFind, StrIMatch | ✅ | |
| TestMath2 | RoundI64, FloorI64, CeilI64, F64, Sqrt, Sin, Cos | ✅ | CeilI64 bug confirmed for negatives |
| TestMemUtil | CAlloc, MemSet, MemCpy, MemCmp | ✅ | |
| TestTypeConv | U8/U16/I8/I16 local variable behavior | ✅ | Locals do NOT truncate on assignment |
| TestMemSet2 | MemSetU16, MemSetI64 | ✅ | |
| TestBitOps | AND/OR/XOR/NOT, shifts, Bt/Bts/Btr/Bsf/Bsr | ✅ | |
| TestException | try/catch/throw, hardware exceptions, nesting, propagation | ✅ | 13/13 pass |

---

## Tier 1 — Kernel Prerequisites

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestStruct | class/struct syntax, field access, nested structs, sizeof | ✅ | 15/15 pass |
| TestI64Edge | I64_MAX/MIN, overflow, I64_MIN/-1 | ✅ | 7 pass, 8 obs — I64_MIN/-1 silently wraps (NEG not IDIV); all overflow is silent 2's complement |
| TestPointers | Pointer arithmetic, NULL deref, address-of, casting | ⏸ | Deferred — revisit after Tier 1 |

---

## Tier 2 — Infrastructure

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestGlobals | Global variable persistence, init behavior | ✅ | 11/11 pass — globals NOT zero-initialized by default; persist correctly across calls |
| TestFmtSpec | StrPrint %X, %b, width/padding specifiers | ✅ | 18/18 pass — %-N left-align ignored; %e no + in exponent; %,d thousands; %,X groups by 4 |
| TestFnPtr | HolyC function pointers, callbacks | ✅ | 12/12 pass — typed fp locals unsupported; use global fp declarations |

---

## Tier 3 — Kernel Utilities

These round out API coverage and are directly relevant to the networking/hardware roadmap.

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestDirOps | DirMk, FilesFind, Del on dirs, directory traversal | ✅ | 10/10 pass — Del(path,FALSE,TRUE) required to delete dirs; Del alone is files-only |
| TestF64Edge | F64 infinity, overflow, NaN, special values | ✅ | 15/15 — FP exceptions masked; NaN==NaN→1 (non-IEEE); 0.1+0.2==0.3 (x87 80-bit); F64 locals in fns crash OS (use globals) |
| TestDateTime | Now(), Date2Struct, SysTimerRead, tS, Sleep | ✅ | 14/14 pass — Struct2Date + NowDateTimeStruct panic from JIT context; skipped |
| TestQSort | QSort on integer and string arrays | ✅ | 11/11 pass — QSortI64 for ints, QSort(width=8) for string ptrs; comparators must be global fns |
| TestKernelUtils | BCnt (count set bits), EndianU16/U32/I64 (byte-swap) | ✅ | 18/18 pass — all pure computation; round-trip confirmed; ready for network use |

---

## Tier 4 — OS Primitives

Riskier tests — spawned tasks or hardware access could panic the OS.
Each should run standalone (not via TestRunner) until stability is confirmed.

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestTasks | Spawn, Kill, DeathWait, TaskValidate, Yield, arg passing | ✅ | 8/8 pass — tasks work from REPL context; DeathWait does NOT null the ptr; neg args work; standalone only |
| TestPCI | PCI bus enumeration via PCIReadU16/U32/U8, PCIClassFind — detect e1000 NIC | ✅ | 10/10 pass — TempleOS uses BIOS-based PCIReadXX not raw port I/O; e1000 at bus=0,dev=3,func=0 (8086:100E); standalone only |

---

## Backfill — Tier 1B (now unblocked)

Deferred earlier; now relevant as prerequisites for pointer-heavy driver work.

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestPointers | Pointer arithmetic, address-of, casting, struct ptr, double ptr, buf_cast | ✅ | 9/9 pass — all pointer patterns work; buf_cast (typed ptr at offset) confirmed for packet parsing |
| TestStrConv | Str2I64, Str2F64, StrScan, MStrPrint | ✅ | 20/20 pass + 1 obs — 0o octal prefix unsupported (use radix=8); Str2F64 exp notation needs range check not == |

---

## Tier 5 — e1000 NIC Driver

Build a working NIC driver from scratch. TempleOS is identity-mapped (phys == virt), so BAR0 MMIO is directly accessible via pointer dereference. All standalone — NIC init/Tx/Rx could panic if descriptor rings are malformed.

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestE1000BAR | Read BAR0 MMIO base addr via PCIReadU32; probe status, CTRL, RCTL, TCTL, MAC via RAL/RAH | ✅ | 11/11 pass — BAR0=0xFEB80000, CTRL=0x00140240, STATUS=link-up+FD, MAC=52:54:00:12:34:56; standalone only |
| TestE1000MAC | Read burned-in MAC address from e1000 EEPROM / RAL/RAH registers | ✅ | Covered by TestE1000BAR (RAL0/RAH0 tests); MAC confirmed as 52:54:00:12:34:56 |
| TestE1000Init | Full NIC init: reset, set MAC, RX/TX descriptor rings, enable | ⏳ | High risk — malformed ring setup can panic; do last |
| TestE1000Tx | Transmit a raw Ethernet frame (ARP request or padding frame) | ⏳ | Requires TestE1000Init passing |
| TestE1000Rx | Receive a frame — may use QEMU loopback or ICMP echo from host | ⏳ | Requires TestE1000Init + Tx working |

---

## Tier 6 — Protocol Building Blocks

Pure computation first (no hardware) — packet construction and checksum. Safe to add to TestRunner once stable.

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestArpPkt | ARP packet construction + field parsing (pure computation) | ⏳ | No hardware; validates byte-packing of Ethernet+ARP headers |
| TestIPv4Pkt | IPv4 header construction, ones-complement checksum | ⏳ | Checksum algo must be confirmed before sending real packets |
| TestUDPPkt | UDP header + checksum (needs IP pseudo-header) | ⏳ | Depends on TestIPv4Pkt checksum being correct |
| TestICMP | ICMP echo request via e1000 Tx, receive reply via Rx | ⏳ | First live network round-trip; requires Tier 5 complete |

---

## Tier 7 — Application Layer

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestDHCP | DHCP discover/offer/request/ack — get IP from QEMU's built-in DHCP | ⏳ | Requires UDP stack; QEMU provides DHCP on 10.0.2.2 by default |
| TestHTTPGet | HTTP GET request to host via QEMU user-mode network (10.0.2.2:80) | ⏳ | End goal — requires full stack: e1000 + IP + TCP + HTTP |
