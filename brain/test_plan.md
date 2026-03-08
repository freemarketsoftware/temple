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
| TestDolDoc | DocNew, DocSize, DocPrint, DocLock/Unlock, DocRst, DocDel, DocFind, entry walk | ✅ | 14/14 pass — in-memory CDoc ops safe from ExeFile context; DocSize(fresh)=1208B; DocPrint plain→NULL, $$FG$$→entry; lock reentrant→FALSE; DocRst restores baseline; DocFind hit/miss; 2 entries for "hello\n" |

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
| TestE1000Init | Full NIC init: reset, set MAC, RX/TX descriptor rings, enable | ✅ | 10/10 pass — bar0_addr, pci_bus_master, ctrl_rst_cleared, status_lu_fd, TDBAL/TDBAH/TDLEN/TDH/TDT/TCTL all confirmed |
| TestE1000Tx | Transmit a raw Ethernet frame (ARP request or padding frame) | ✅ | 8/8 pass — DD=1, TXDW=1, TXQE=1, TPT=1; **critical: PCIWriteU16(0,3,0,0x04,0x0107) required to enable Bus Master before DMA works** |
| TestE1000Rx | Receive a frame — may use QEMU loopback or ICMP echo from host | ✅ | 8/8 pass — ARP request to 10.0.2.2; SLiRP replies with ARP reply (len=68, EtherType=0806, OPER=0002); **CRITICAL: Sleep(2000) required — e1000_receive_iov line 923 returns 0 while flush_queue_timer pending (1000ms virtual time after RCTL write); timer fires → delivers packet** |

---

## Tier 6 — Protocol Building Blocks

Pure computation first (no hardware) — packet construction and checksum. Safe to add to TestRunner once stable.

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestArpPkt | ARP packet construction + field parsing (pure computation) | ✅ | 13/13 pass — ArpBuildRequest helper confirmed; all ARP fields, byte layout, IPs verified |
| TestIPv4Pkt | IPv4 header construction, ones-complement checksum | ✅ | 10/10 pass — IPv4Cksum verified: cksum_raw=0x22C1 for src=10.0.2.15→dst=10.0.2.2 UDP/28; verify=0 |
| TestUDPPkt | UDP header + checksum (needs IP pseudo-header) | ✅ | 8/8 pass — UDPCksum+pseudo-header verified=0; **NOTE: block-scoped `I64 x=0,i;` inside `{}` panics OS — declare all vars at function top** |
| TestICMP | ICMP echo request via e1000 Tx, receive reply via Rx | ✅ | 8/8 pass — ARP→ICMP echo req→reply; gw_mac=52:55:0A:00:02:02; id/seq echoed back; cksum_valid=0; iters=0 (synchronous after flush_queue_timer fires during ARP Sleep); standalone only |

---

## Tier 7 — Application Layer

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestDHCP | DHCP discover/offer/request/ack — get IP from QEMU's built-in DHCP | ✅ | 8/8 pass — Discover→Offer(10.0.2.15)→Request→Ack; xid=12345678 echoed; **BUG: `continue` unsupported in HolyC — use if/else**; standalone only |
| TestHTTPGet | HTTP GET request to host via QEMU user-mode network (10.0.2.2:8080) | ✅ | 8/8 pass — SYN→SYN-ACK→ACK+GET→HTTP 200; server_isn=0000FA01; ip_total_len=198; rx1 has payload (no pure-ACK from SLiRP); standalone only |
| TestHTTPPost | HTTP POST to agent_server.py on host:8081; server echoes ECHO:<body> | ✅ | 8/8 pass — SYN→SYN-ACK→ACK+POST→200+ECHO; Content-Length:13; "ECHO:" confirmed in response; payload=157; standalone only |

---

## Tier 3B — UI / Graphics

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestDolDoc2 | DocEntryDel, entry type_u8, DocAnchorFind | ✅ | 9/9 pass — ternary crashes HolyC; DocWrite/DocRead/DocGoToLine deferred (DocGoToLine calls DocRecalc(RECALCt_FIND_CURSOR)+DCAlias which is risky from ExeFile) |
| TestGrPalette | GrPaletteColorSet/Get round-trip, 16-color values, restore | ✅ | 8/8 pass — VGA DAC 6-bit; exact round-trip for 0x0000/0x5555/0xAAAA/0xFFFF; PaletteSetStd restores |
| TestTextBase | TextRect, gr.text_base read/write, attr byte packing | ✅ | 5/5 pass — cell = (attr<<8)|char as U32; TEXT_COLS=80; row 0 used for writes; restored after |
| TestGrDraw | DCNew/DCDel, GrRect, GrLine, GrFillCircle on offscreen DC | ✅ | 7/7 pass — dc->body pixel read-back; GrRect retval=1024 (32*32); all primitives draw color 15 |
| TestMath3 | Arg (ATan2), Exp, Ln, Log2, Log10, Pow — complete math API coverage | ✅ | 17/17 pass — all F64 global (locals crash JIT); Arg(x,y)=atan2(y,x); range checks for non-exact FP results |
| TestRegistry | RegWrite, RegExe, RegDft, RegCnt | ✅ | 10/10 pass — RegExe executes stored HolyC and returns I64; RegDft: FALSE=new, TRUE=existed; RegCnt: 4 entries for "42;\n" content; stored as HolyC in ~/Registry.HC.Z |
| TestGrPrint | GrPrint on offscreen DC — font rendering, color index, fmt args | ✅ | 6/6 pass — GrPrint(dc, x, y, "fmt", ...) uses dc->color; FONT_WIDTH=8 FONT_HEIGHT=8; pixels = color index 0-15; retval=1 |
| TestShiftEdge | Shift edge cases: SAR, large counts, boundary I64 values | ✅ | 10 pass 2 OBS — SAR fills with sign bit; I64_MAX<<1=-2; x86 masks count mod 64: 1<<64=1, 1<<127=I64_MIN |
| TestMemOverlap | MemCpy overlap behavior (MemMove absent) | ✅ | 4 pass 2 OBS — forward overlap (dst<src) works; backward overlap corrupts tail (REP MOVSB reads overwritten bytes); MemMove does not exist |
| TestSwitch | switch/case, default, range cases (case N...M:), fall-through | ✅ | 12/12 pass — range syntax is `...` (3 dots); negative ranges work; fall-through confirmed; char ranges 'A'...'Z' work |
| TestDefine | #define constant macros (object-like only) | ✅ | 9/9 pass — constant macros work; function-like macros with args corrupt HolyC JIT preprocessor state (see bugs.md) |
| TestStrEdge | StrPrint/StrCpy/StrNew/CatPrint return values and edge cases | ✅ | 9/9 pass — StrPrint returns dst U8*; StrCpy is U0 (void); StrNew heap-copies; CatPrint returns dst |
| TestGrExtra | GrPlot, GrFloodFill, GrEllipse on offscreen DC | ✅ | 8/8 pass — GrPlot returns Bool; GrFloodFill fills whole cleared DC (retval=1024=32*32); GrEllipse outline only (center empty) |
| TestCompress | CompressBuf/ExpandBuf roundtrip | ✅ | 7/7 pass — short string, repetitive data, longer text all roundtrip correctly; both buffers caller-freed |
| TestHashKernel | HashFind on Fs->hash_table for kernel and user symbols | ✅ | 7/7 pass — HTT_FUN=0x40; finds MAlloc/StrLen/StrPrint/TestMalloc; miss returns NULL; mask=-1 also works; sym->str matches searched name |

---

## Tier 8 — Agent Infrastructure

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| AgentLoop.HC | TCP command/result loop — poll GET /cmd, ExeFile, POST /result | ✅ | 7/7 pass (PONG, arithmetic, string, uptime, eval_i64, define+call, task_list); RST+ACK after each HTTP response prevents SLiRP zombie connections filling the 8-slot RX ring; Fs used for task ring walks (Adam is a function, not CTask*); driven by test_agent.py + Agent class (serial/agent.py) |
| run_tests.py  | Full HolyC test suite via Agent lifecycle | ✅ | 45 suites / 437 passed, 1 failed (str2i64_oct_prefix — known), 41 obs; uses Agent.start(pre_deploy=...) to deploy test files before AgentLoop launches, then ag.stop() before ag.read_file() to free the serial REPL |
