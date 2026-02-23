# Test Plan

Tracks what has been tested, what is pending, and what is deferred.
Update this file as tests are written and results are confirmed.

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
| TestFnPtr | HolyC function pointers, callbacks | ⏳ | |

---

## Tier 3 — Nice to Have

| Test File | Area | Status | Notes |
|-----------|------|--------|-------|
| TestDirOps | DirMk, nested dirs, Del on dirs | ⏳ | |
| TestF64Edge | F64 infinity, overflow, special values | ⏳ | |
