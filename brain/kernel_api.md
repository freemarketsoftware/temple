# TempleOS Kernel API Reference

Verified functions from source tree (`brain/real-temple-tree/`).

---

## Strings

| Function | Signature | Notes |
|----------|-----------|-------|
| `StrLen` | `I64 StrLen(U8 *str)` | Compiler intrinsic |
| `StrCpy` | `U0 StrCpy(U8 *dst, U8 *src)` | |
| `StrCmp` | `I64 StrCmp(U8 *a, U8 *b)` | 0=equal, <0=less, >0=greater |
| `StrICmp` | `I64 StrICmp(U8 *a, U8 *b)` | Case-insensitive compare |
| `StrNCmp` | `I64 StrNCmp(U8 *a, U8 *b, I64 n)` | Compare first N bytes |
| `StrNICmp` | `I64 StrNICmp(U8 *a, U8 *b, I64 n)` | Case-insensitive, N bytes |
| `StrMatch` | `U8 *StrMatch(U8 *needle, U8 *haystack)` | Find needle in haystack; returns ptr or NULL |
| `StrIMatch` | `U8 *StrIMatch(U8 *needle, U8 *haystack)` | Case-insensitive StrMatch |
| `StrFind` | `U8 *StrFind(U8 *needle, U8 *haystack, I64 flags=0)` | Find with options |
| `StrOcc` | `I64 StrOcc(U8 *src, I64 ch)` | Count occurrences of a char |
| `StrNew` | `U8 *StrNew(U8 *buf, CTask *mem_task=NULL)` | MAlloc + copy; caller frees |
| `StrPrint` | `U8 *StrPrint(U8 *dst, U8 *fmt, ...)` | sprintf |
| `CatPrint` | `U8 *CatPrint(U8 *dst, U8 *fmt, ...)` | Append formatted string — **use instead of StrCat** |

**No StrCat** — use `CatPrint(dst, "%s", src)` to append.
**No StrUpr/StrLwr** — use `StrUtil(src, SUF_TO_UPPER)` / `StrUtil(src, SUF_TO_LOWER)`.
**No StrRev, StrTrim.**

---

## Memory

| Function | Signature | Notes |
|----------|-----------|-------|
| `MAlloc` | `U8 *MAlloc(I64 size, CTask *mem_task=NULL)` | |
| `CAlloc` | `U8 *CAlloc(I64 size, CTask *mem_task=NULL)` | Zero-initialized |
| `Free` | `U0 Free(U8 *addr)` | |
| `MSize` | `I64 MSize(U8 *src)` | Size of allocation |
| `MemCpy` | `U8 *MemCpy(U8 *dst, U8 *src, I64 cnt)` | Returns dst |
| `MemCmp` | `I64 MemCmp(U8 *a, U8 *b, I64 cnt)` | 0=equal, 1=a>b, -1=a<b |
| `MemSet` | `U0 MemSet(U8 *dst, U8 val, I64 cnt)` | Fill with byte |
| `MemSet_U16` | `U0 MemSet_U16(U8 *dst, U16 val, I64 cnt)` | Fill with 16-bit word |
| `MemSet_I64` | `U0 MemSet_I64(U8 *dst, I64 val, I64 cnt)` | Fill with 64-bit qword |

---

## File I/O

| Function | Signature | Notes |
|----------|-----------|-------|
| `FileWrite` | `I64 FileWrite(U8 *path, U8 *buf, I64 size, CDate cdt=0, I64 attr=0)` | Returns disk sector index (NOT byte count) — increments by 2 per call |
| `FileRead` | `U8 *FileRead(U8 *path, I64 *_size=NULL, I64 *_attr=NULL)` | Returns MAlloced buf; caller frees |

---

## Math

| Function | Signature | Notes |
|----------|-----------|-------|
| `AbsI64` | `I64 AbsI64(I64 n)` | Integer abs — **not `Abs`** (that's F64) |
| `MinI64` | `I64 MinI64(I64 n1, I64 n2)` | Integer min — **not `Min`** (that's F64) |
| `MaxI64` | `I64 MaxI64(I64 n1, I64 n2)` | Integer max — **not `Max`** (that's F64) |
| `SignI64` | `I64 SignI64(I64 n)` | Returns -1, 0, or 1 |
| `ClampI64` | `I64 ClampI64(I64 num, I64 lo, I64 hi)` | Clamp to range |
| `SqrI64` | `I64 SqrI64(I64 n)` | n * n |
| `Min` | `F64 Min(F64 n1, F64 n2)` | Floating point only |
| `Max` | `F64 Max(F64 n1, F64 n2)` | Floating point only |
| `Clamp` | `F64 Clamp(F64 d, F64 lo, F64 hi)` | Floating point only |

**I64 constants:** `I64_MAX` = `0x7FFFFFFFFFFFFFFF`, `I64_MIN` = `-0x8000000000000000` (defined in KernelA.HH)

**StrPrint format:** `%d` for I64, `%f` for F64 — do NOT use `%d` on F64 results.

---

## HolyC Notes

- **Ternary `?:`** is unreliable with pointer/comparison conditions — use `if/else` to assign a `U8 *status` variable, then use `status` in `StrPrint`. Integer ternary may also fail. Safest: always use `if/else`.
- Default arguments supported: `MAlloc(64)` uses `mem_task=NULL`
- 255-byte line limit in `exec_str` (lexer hard limit); use `run_hc()` for longer code
- No `StrCat`, no `Abs` — see table above for correct names
