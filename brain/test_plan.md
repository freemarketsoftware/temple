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
| TestQSort | QSort on integer and string arrays | ⏳ | |
| TestKernelUtils | BCnt (count set bits), EndianU16/U32/I64 (byte-swap) | ⏳ | Endian functions needed for network protocol work |

---

## Tier 4 — OS Primitives

Riskier tests — spawned tasks or hardware access could panic the OS.
Each should run standalone (not via TestRunner) until stability is confirmed.

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestTasks | Spawn, Kill, DeathWait, task data passing | ⏳ | Run standalone — a bad task can panic the runner |
| TestPCI | PCI bus enumeration via InU32(0xCF8/0xCFC) — detect e1000 NIC | ⏳ | First step toward HTTP stack; read-only probe, low risk |
