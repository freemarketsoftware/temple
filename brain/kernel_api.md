# TempleOS Kernel API Reference

Verified functions from source tree (`brain/real-temple-tree/`).

---

## Strings

| Function | Signature | Notes |
|----------|-----------|-------|
| `StrLen` | `I64 StrLen(U8 *str)` | |
| `StrCpy` | `U0 StrCpy(U8 *dst, U8 *src)` | |
| `StrCmp` | `I64 StrCmp(U8 *a, U8 *b)` | 0=equal, <0=less, >0=greater |
| `StrICmp` | `I64 StrICmp(U8 *a, U8 *b)` | Case-insensitive |
| `StrNew` | `U8 *StrNew(U8 *buf, CTask *mem_task=NULL)` | MAlloc + copy; caller frees |
| `StrPrint` | `I64 StrPrint(U8 *dst, U8 *fmt, ...)` | sprintf |
| `CatPrint` | `U8 *CatPrint(U8 *dst, U8 *fmt, ...)` | Append formatted string — **use instead of StrCat** |

**No StrCat** — use `CatPrint(dst, "%s", src)` to append.

---

## Memory

| Function | Signature | Notes |
|----------|-----------|-------|
| `MAlloc` | `U8 *MAlloc(I64 size, CTask *mem_task=NULL)` | |
| `CAlloc` | `U8 *CAlloc(I64 size, CTask *mem_task=NULL)` | Zero-initialized |
| `Free` | `U0 Free(U8 *addr)` | |
| `MSize` | `I64 MSize(U8 *src)` | Size of allocation |

---

## File I/O

| Function | Signature | Notes |
|----------|-----------|-------|
| `FileWrite` | `I64 FileWrite(U8 *path, U8 *buf, I64 size, CDate cdt=0, I64 attr=0)` | Returns bytes written |
| `FileRead` | `U8 *FileRead(U8 *path, I64 *_size=NULL, I64 *_attr=NULL)` | Returns MAlloced buf; caller frees |

---

## Math

| Function | Signature | Notes |
|----------|-----------|-------|
| `Min` | `F64 Min(F64 n1, F64 n2)` | Floating point |
| `Max` | `F64 Max(F64 n1, F64 n2)` | Floating point |
| `AbsI64` | `I64 AbsI64(I64 n)` | Integer absolute value — **not `Abs`** |

---

## HolyC Notes

- **Ternary `?:`** is unreliable with pointer/comparison conditions — use `if/else` to assign a `U8 *status` variable, then use `status` in `StrPrint`. Integer ternary may also fail. Safest: always use `if/else`.
- Default arguments supported: `MAlloc(64)` uses `mem_task=NULL`
- 255-byte line limit in `exec_str` (lexer hard limit); use `run_hc()` for longer code
- No `StrCat`, no `Abs` — see table above for correct names
