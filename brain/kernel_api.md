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
| `MemSetU16` | `U16 *MemSetU16(U16 *dst, I64 val, I64 U16cnt)` | Fill with 16-bit word; cnt = number of U16s |
| `MemSetI64` | `I64 *MemSetI64(I64 *dst, I64 val, I64 I64cnt)` | Fill with 64-bit qword; cnt = number of I64s |

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

**Integer division truncates toward zero** (C standard): `-7 / 2 = -3`, `7 / -2 = -3`.

**Integer modulo sign follows the dividend** (C truncation-toward-zero): `-7 % 3 = -1`, `7 % -3 = 1`, `-7 % -3 = -1`. The sign of `a % b` always matches the sign of `a`, regardless of `b`. This is the same as C99 and differs from Python's floor-division modulo.

**Integer overflow is silent** — wraps in 2's complement, no exception thrown. `I64_MAX + 1 = I64_MIN`.

**`I64_MIN / -1` does not throw** — the compiler converts division by -1 to a NEG instruction, so no hardware IDIV overflow fault. Result wraps silently to `I64_MIN`.

**Arithmetic right shift** — `>>` on signed I64 is SAR (arithmetic), not SHR (logical). Sign bit is preserved: `-1 >> 63 = -1`, `-8 >> 1 = -4`.

**StrPrint format specifiers (confirmed):**

| Specifier | Output | Notes |
|-----------|--------|-------|
| `%d` | Signed decimal | Standard |
| `%u` | Unsigned decimal | `-1` → `18446744073709551615` |
| `%x` | Lowercase hex | `255` → `ff` |
| `%X` | Uppercase hex | `255` → `FF` |
| `%b` | Binary | `5` → `101`, `255` → `11111111` |
| `%f` | Float, 0 decimal places | `3.14` → `3` |
| `%.Nf` | Float, N decimal places | `%.2f` of `3.14` → `3.14` |
| `%e` | Scientific notation | `12345.0` → `1.23450000e4` (no `+`, no leading 0 in exp) |
| `%g` | General float | Behaves unexpectedly — avoid |
| `%n` | Engineering notation | Same as `%e` without args; SI prefixes need extra setup |
| `%c` | Single character | `'A'` → `A` |
| `%s` | String | Standard |
| `%p` | Pointer | Printed as uppercase hex, no `0x` prefix |
| `%%` | Literal `%` | Standard |
| `%Nd` | Right-align in width N | `%5d` of `42` → `   42` |
| `%0Nd` | Zero-pad to width N | `%05d` of `42` → `00042` |
| `%-Nd` | Left-align (broken) | **Ignored** — behaves same as `%Nd`, still right-aligns |
| `%,d` | Thousands separator | `1234567` → `1,234,567` |
| `%,X` | Hex with separator | `0xDEADBEEF` → `DEAD,BEEF` (groups of 4) |

**`%f` prints 0 decimal places by default** (truncates to integer). Use `%.2f` for 2 decimal places, `%.6f` for 6, etc.
**`%-N` left-justify flag is non-functional** — always right-aligns. Use manual padding if left-alignment is needed.
**MemCmp returns:** -1 when a<b, 0 when equal, 1 when a>b (not arbitrary negative/positive like C's memcmp).

---

## HolyC Type System Notes

- **Local variables are 64-bit** — `U8 x; x = 256;` stores 256, NOT 0. Type declarations do NOT truncate on assignment for locals. Use explicit `& 0xFF` masking if clamping is needed.
- **Struct fields DO truncate** — memory-layout types (struct members, arrays indexed via pointer) respect byte width.
- **Sign extension when loading to I64**: `I8 x = -1; I64 r = x;` → r = -1 (sign-extended). `U8 x = 0xFF; I64 r = x;` → r = 255 (zero-extended).
- **Typed local arrays work**: `U16 arr[4]; I64 arr2[2];` — valid stack declarations, correct byte layout.
- **Postfix cast `p(Type *)` can be unreliable for pointer variables** — use typed local arrays or struct members instead to avoid cast issues.
- **Global variables are NOT zero-initialized** — an uninitialized global holds whatever value is in memory at startup (garbage). Always initialize explicitly: `I64 g_counter = 0;`. Exception: `CAlloc` for heap structs still zero-fills.

## Exception Handling

HolyC exceptions use `try`/`catch`/`throw` with no parameters on the catch block.

```c
try {
  throw('MyCode');       // I64 code, up to 8 ASCII chars packed
} catch {
  // Fs->except_ch holds the thrown code
  if (Fs->except_ch == 'MyCode') { ... }
  Fs->catch_except = TRUE;  // MUST set this or exception re-propagates
}
```

| Concept | Detail |
|---------|--------|
| `throw(code)` | Raises exception with I64 code. Multi-char literal: `throw('DivZero')` |
| `Fs->except_ch` | I64 exception code, readable inside catch block |
| `Fs->catch_except = TRUE` | **Required** in catch block — omitting this re-propagates the exception to the outer scope |
| Hardware div-by-zero | Throws `'DivZero'` automatically |
| Uncaught exception | Calls `Panic()` → OS death |
| Cross-function propagation | Exceptions propagate from called functions to the caller's `try/catch` — confirmed |

**Special exception codes:** `'Compiler'` is intercepted by the OS exception system and does not surface through user `try/catch` in the normal way. All other codes (including 8-char custom codes) work normally.

**Printing the exception code as a string:**
```c
U8 ecode[9]; I64 ec;
ec = Fs->except_ch;
MemCpy(ecode, &ec, 8);
ecode[8] = 0;
// ecode is now a null-terminated string like "DivZero"
```

---

## HolyC Notes

- **Typed function pointer locals are unsupported** — `I64 (*fp)(I64 x) = &Fn;` inside a function body silently prevents the function from executing. Always declare function pointer variables at **global scope** (`I64 (*g_fp)(I64 x) = 0;`) and assign/call them from inside functions. Plain `I64 fp = &Fn;` (assign only) is safe as a local but calling via it fails too.
- **Ternary `?:`** is unreliable with pointer/comparison conditions — use `if/else` to assign a `U8 *status` variable, then use `status` in `StrPrint`. Integer ternary may also fail. Safest: always use `if/else`.
- Default arguments supported: `MAlloc(64)` uses `mem_task=NULL`
- 255-byte line limit in `exec_str` (lexer hard limit); use `run_hc()` for longer code
- No `StrCat`, no `Abs` — see table above for correct names

---

## Functions That Do NOT Exist

Confirmed undefined in TempleOS — do not use these.

| Name | What it looks like | Correct alternative |
|------|--------------------|---------------------|
| `Eval(str)` | Execute arbitrary HolyC string | Use `SerReplExe` / `ExeFile` workaround |
| `ExeStr(str)` | Execute arbitrary HolyC string | Use `SerReplExe` / `ExeFile` workaround |
| `MkDir(path)` / `MakeDir(path)` | Create directory | `DirMk(path)` |
| `DirFirst(pattern)` | Iterate directory entries | `FilesFind(mask)` — walk returned linked list |
| `DirNext(entry)` / `FilesNext(entry)` | Next directory entry | Walk `FilesFind` linked list via pointer |
| `FOpen(path)` | Open file handle (C-style) | `FileRead` / `FileWrite` for whole-file I/O |
| `FPrint(handle, fmt)` | Print to file handle | `StrPrint(buf, fmt, ...)` + `FileWrite` |
| `Cls` | Clear terminal | `DocClear(DocPut)` |
| `(Type)value` | C-style prefix cast | TempleOS postfix cast: `value(Type)` |
| `!expr` | Logical NOT | `\!expr` (escape required) |
| `!=` | Not-equal operator | `\!=` (escape required) |
