# Bug List

Active issues, known problems, and notable findings to investigate.

---

## Primitives

### Snapshot load reverts TempleOS filesystem
- **Status:** Resolved (2026-02-23) — `serial/sync_mirror.py` + saved snapshots cover this
- **Cause:** `loadvm` reverts the qcow2 disk to the snapshot state. Any files deployed to TempleOS after the snapshot was taken are lost.
- **Fix:** Always run `sync_mirror.py` before saving a snapshot to capture current state. After any `loadvm`, re-deploy changed files if needed. All primitives are included in snap1 as of 2026-02-23.

### sync_mirror.py is VM→local only; new primitive files need explicit write_file
- **Status:** Confirmed (2026-02-23)
- **Detail:** `sync_mirror.py` reads FROM TempleOS TO `brain/real-temple-tree/`. It does NOT write local files to the VM. Any new primitive `.HC` file created locally must be deployed via `t.write_file('C:/Home/Ser*.HC', content)` before it can be `#include`-d. Existing primitives (SerDir, SerFileRead, etc.) are already in snap1, so they persist across `loadvm`. New primitives added after snap1 must be written each session.
- **Fix pattern:** In `freeze()`, call `self.write_file('C:/Home/SerPrint.HC', _SERPRINT_HC)` before the `send_cmd('#include ...')`. The `_SERPRINT_HC` constant in `temple.py` is the source of truth.

---

## Stability

### SerSymList.HC may cause kernel panic
- **Status:** Suspected, not confirmed
- **Cause:** SerSymList.HC walks the TempleOS hash table using raw pointer arithmetic (`CHashTable *t=Fs->hash_table; h=t->body[i]`). Accessing stale or freed entries could fault.
- **Reproduce:** Include SerSymList.HC and call `SerSymList(64);` — monitor for kernel panic.
- **Next step:** Reduce the scope of the walk (limit iterations or null-check more aggressively) and test.

### Kernel panic during test_kernel_basic.py
- **Status:** Occurred once (2026-02-22)
- **Likely cause:** SerSymList.HC or SerMemInfo.HC being included when the primitive files were missing, causing ExeFile to fail. If the error propagates in an unexpected way, the REPL or kernel may panic.
- **Next step:** Re-run test_kernel_basic.py after redeploying all primitives and confirm if panic recurs.

---

## Protocol

### Dir; required to trigger SerReplExe startup
- **Status:** Known behavior, not a bug per se — documented here for reference
- **Detail:** After `#include "C:/Home/SerReplExe.HC"` via sendkey, TempleOS needs `Dir;` sent as a second keyboard command for SerReplExe to fully initialize and send REPL_READY over serial. Without `Dir;`, `is_frozen()` will always return False even if SerReplExe compiled successfully.
- **Workaround:** Rule 6 covers this — always send `Dir;` after the include. See `serial/temple.py freeze()`.

### SerReplExe exception scope: div-by-zero in called function kills REPL
- **Status:** FIXED (2026-02-22) — SerReplExe wraps `ExeFile` in `try/catch`; exceptions from called functions are caught and reported as `EXCEPT:<name>` over serial.
- **Fix detail:** SerReplExe.HC uses `try{ExeFile(...);}catch{...StrPrint(ex,"EXCEPT:%s",ecode);}`. Confirmed: `throw('DivZero')` and hardware div-by-zero in called functions both return `EXCEPT:DivZero` without killing the REPL. TestException 13/13 pass.
- **Remaining limitation:** `throw('Compiler')` is a TempleOS system exception that appears to be intercepted specially; it does not produce an `EXCEPT:` response. All other exception codes (including 8-char custom codes like `'TestCode'` and `'ABCDEFGH'`) work correctly.

### FINDING: 'Compiler' exception code is intercepted by TempleOS
- **Status:** Confirmed (2026-02-22)
- **Detail:** `throw('Compiler')` from user code does not produce `EXCEPT:Compiler` from SerReplExe — only `OK` is returned. 8-char custom exception codes (`'TestCode'`, `'ABCDEFGH'`) work correctly. This suggests TempleOS intercepts the 'Compiler' exception code at the system level before it reaches SerReplExe's catch block, or it handles it through a different dispatch path.
- **Impact:** Low — 'Compiler' is a real compiler error thrown only during compilation failures. User code should not intentionally throw this code.

---

## Kernel Bugs

### BUG: Use-after-free is silent — no detection, no crash
- **Status:** Confirmed (2026-02-22)
- **Severity:** High — heap corruption goes undetected
- **Behavior:** Writing to a freed pointer (`p[0] = 0x41` after `Free(p)`) does not crash. A subsequent `MAlloc(64)` returns successfully. The corruption is silent — there is no guard page, no canary, no allocator check.
- **Related:** MAlloc immediately reuses the freed address for the next same-size allocation. So a use-after-free write directly corrupts the next allocation's data.
- **Evidence:** `write_after_free` survived, `alloc_after_uaf` returned non-null. `reuse_same_addr` = yes (same pointer returned on next alloc of same size).
- **Source to investigate:** `Kernel/Mem/MAllocFree.HC`

### BUG: Double-free causes kernel panic
- **Status:** Confirmed (2026-02-22)
- **Severity:** High — any use-after-free or double-free crashes the entire OS
- **Behavior:** `Free(p); Free(p);` immediately panics TempleOS. No error is reported, no exception is thrown — the kernel just dies.
- **Root cause:** TempleOS's allocator has no double-free detection. The second `Free` likely corrupts heap metadata, causing a hardware fault on the next memory access.
- **Impact:** Any bug that frees a pointer twice will panic the machine, with no way to recover short of a snapshot restore.
- **Source to investigate:** `Kernel/Mem/MAllocFree.HC`

### BUG: MAlloc panics on OOM instead of returning NULL
- **Status:** Confirmed (2026-02-22)
- **Severity:** High — crashes the entire system on large allocations
- **Behavior:** `MAlloc(size)` panics TempleOS when `size` exceeds available heap (~256–320MB in a 512MB VM). A correct allocator should return NULL on failure.
- **Evidence:** `MAlloc(256MB)` succeeds and returns non-null. `MAlloc(320MB)` causes immediate kernel panic (serial goes silent, REPL unresponsive). Threshold is between 256MB and 320MB.
- **Root cause:** TempleOS's allocator likely does not check for heap exhaustion before writing — it probably just bumps a pointer past the end of available memory, causing a hardware page fault in kernel mode.
- **Impact:** Any code path that allocates unbounded memory (e.g., reading a large file) can crash the OS with no recovery.
- **Source to investigate:** `Kernel/Mem/MAllocFree.HC`

### BUG: CeilI64 gives wrong result for negative numbers
- **Status:** Confirmed (2026-02-22)
- **Severity:** Low — affects negative-number rounding only
- **Behavior:** `CeilI64(-7, 4)` returns `-8` instead of `-4`. The source adds `to-1` before truncating, but then subtracts `to` again, yielding floor behavior for negative inputs.
- **Evidence:** `CeilI64(-7, 4)` = -8. Expected = -4 (ceil toward +inf).
- **Root cause:** `Kernel/KMathB.HC` — the else branch `num+=to-1; return num-num%to-to;` is equivalent to FloorI64 for negative numbers.
- **Workaround:** For negative inputs, use `-(FloorI64(-num, to))` or compute manually.

---

## HolyC Language Behavior

Rules that differ from C and apply everywhere, not just specific files.

### Cast syntax is `expr(type)`, NOT `(type)expr`
- **Status:** Confirmed
- **Detail:** HolyC uses postfix cast syntax: `value(TargetType)`. C-style prefix casts `(type)value` are not used.
- **Examples:** `buf(I64*)`, `d[3](U8*)`, `fp_result(I64)`, `addr(U8*)`
- **Applies to:** pointer casts, integer-to-float, float-to-integer, any type reinterpretation.

### Implicit integer-to-pointer conversion emits "missing ) at U0"
- **Status:** Confirmed (2026-02-23)
- **Detail:** Passing an `I64` value to a function expecting `U8 *` or any pointer type, or assigning `I64` to a pointer variable, causes HolyC's JIT to emit `"missing ) at U0"` to the terminal. The code still compiles and runs, but the warning is noisy and indicates a type mismatch.
- **Fix pattern:** Always cast explicitly using HolyC syntax: `UartPrint(d[3](U8*))`, `ptr = val(I64*)`.
- **Why "missing ) at U0":** The JIT parser encounters the type name `U0` (or another type token) in an unexpected position while resolving the implicit conversion — it expects a `)` instead.
- **Evidence:** SerDir.HC before fix: `UartPrint(d[3])` and `d=d[0]` both generated this warning. After adding explicit casts: silent.

### HolyC `...` variadic forwarding throws `UndefExt`
- **Status:** Confirmed (2026-02-23)
- **Detail:** Defining `U0 Foo(U8 *fmt, ...)` and then calling `StrPrint(buf, fmt, ...)` inside it throws `EXCEPT:UndefExt` at call time. HolyC does not support forwarding a `...` arg list to another variadic function the way C's `va_list`/`va_start` does.
- **Workaround:** Use fixed-arg wrappers with extra I64 params. StrPrint ignores extra args beyond what the format needs, so `U0 SerFmt(U8 *fmt, I64 a, I64 b){StrPrint(buf, fmt, a, b); ...}` is safe to call with only one meaningful arg by padding with 0.
- **Evidence:** `SP3` probe — `SP3("val=%d", 99)` throws `EXCEPT:UndefExt`. `SP4("val=%d", 99, 0)` with fixed 2 args → `b'val=99'` ✓.

### Function pointer parameters are duck-typed at the call site
- **Status:** Confirmed (2026-02-23)
- **Detail:** `Spawn(fn, data, name)` declares `fn` as `U0 (*)(U8 *data)`, but you can pass any `U0 TaskFn(I64 arg)` function and it works — the `data` arg is passed as a 64-bit value regardless of declared type. HolyC does not enforce parameter type matching across function pointer calls.
- **Implication:** Spawn callbacks can declare their arg as `I64` and receive integer values directly: `Spawn(&MyTask, 42, "T")` where `U0 MyTask(I64 arg)` receives `arg=42`.

---

## Notable Findings

### I64_MIN / -1 does NOT throw — compiler eliminates IDIV
- **Status:** Confirmed (2026-02-22)
- **Detail:** `I64_MIN / -1` does not trigger a hardware divide-overflow exception. On x86, IDIV of INT_MIN/-1 should raise DE (#0), same as divide-by-zero. HolyC's JIT compiler appears to convert `x / -1` to a NEG instruction, bypassing IDIV entirely. The result silently wraps back to I64_MIN (since NEG(I64_MIN) = I64_MIN in 2's complement).
- **Impact:** Code that expects `I64_MIN / -1` to throw can't rely on that. Validate divisors independently if -1 is a concern.

### I64 arithmetic overflows silently (2's complement)
- **Status:** Confirmed (2026-02-22)
- **Detail:** All I64 overflow is silent and wraps as expected in 2's complement: I64_MAX+1 = I64_MIN, I64_MIN-1 = I64_MAX, I64_MAX*2 = -2, I64_MAX*I64_MAX = 1. No exception is thrown. This matches standard x86 integer behavior — TempleOS adds no overflow checking.



### MAlloc(0) returns non-null, MSize=0, Free survives
- **Status:** Confirmed (2026-02-22)
- **Detail:** `MAlloc(0)` returns a valid non-null pointer. `MSize(p)` on it returns 0. `Free(p)` does not crash. Benign behavior — consistent with many C allocator implementations.

### MSize(NULL) returns 0, no panic
- **Status:** Confirmed (2026-02-22)
- **Detail:** `MSize(0)` returns 0 without crashing. The allocator has a null guard in MSize (or the metadata read at address 0 returns 0 coincidentally). Either way, it's safe to call.

### MSize on freed pointer reports original size
- **Status:** Confirmed (2026-02-22)
- **Detail:** After `Free(p)`, `MSize(p)` still returns the original allocation size (e.g., 128 for `MAlloc(128)`). The allocator does not zero out or invalidate heap metadata on free.

### MAlloc reuses freed addresses immediately
- **Status:** Confirmed (2026-02-22)
- **Detail:** `p1 = MAlloc(64); Free(p1); p2 = MAlloc(64);` — `p1 == p2`. The allocator returns the exact same address on the next same-size allocation. Combined with the use-after-free bug, this means a stale pointer write directly corrupts the next allocation's content.

### Del(path) does not delete directories by default
- **Status:** Confirmed (2026-02-23)
- **Severity:** Medium — silent no-op, no error reported
- **Behavior:** `Del("C:/path/dir")` silently does nothing when the target is a directory. The directory remains on disk. No error, no exception.
- **Root cause:** `Del()` signature is `I64 Del(U8 *mask, Bool make_mask=FALSE, Bool del_dir=FALSE, Bool print_msg=TRUE)`. The `del_dir` parameter defaults to `FALSE`, so directory deletion is opt-in.
- **Fix:** Use `Del("C:/path/dir", FALSE, TRUE)` to delete directories.
- **Evidence:** `Kernel/BlkDev/DskCopy.HC` — confirmed in source. TestDirOps del_dir test: FAIL with `Del(path)`, PASS with `Del(path, FALSE, TRUE)`.

### FileWrite returns a disk sector index, not byte count
- **Status:** Confirmed (2026-02-22)
- **Detail:** `FileWrite(path, buf, size)` returns an I64 that increments by 2 on each call, regardless of content size. This is a disk sector/block allocation index, not the number of bytes written. The function succeeds and content is correct — only the return value is misleading.
- **Evidence:** Called 4 times with sizes 3, 3, 5, 1 — returned 23129, 23131, 23133, 23135 (always +2).
- **Implication:** Do not use FileWrite's return value to verify write success. Use FileRead + MemCmp instead.

### BUG: F64 local variables inside compiled HolyC functions crash TempleOS
- **Status:** Confirmed (2026-02-23)
- **Severity:** High — silent OS panic, no exception thrown
- **Behavior:** Declaring any `F64` local variable inside a compiled function body (e.g. `F64 x = 1.5;`) causes an immediate OS panic when the function is called. The serial socket goes silent, the REPL dies, and QEMU must be restarted.
- **Also affected:** F64 operations assigned to local variables of any type inside a function.
- **What DOES work:** Declare all F64 state as global variables (`F64 g_val = 0.0;`), then assign and use them from inside functions.
- **Root cause hypothesis:** Same JIT bug as typed function pointer locals — the HolyC compiler does not correctly allocate x87 FPU stack space for F64 locals within a function prologue/epilogue.
- **Workaround:** Move all F64 variables to global scope. All existing tests (TestF64Edge, TestMath2) use this pattern.
- **Evidence:** TestF64Edge — version with local F64 vars panicked immediately on first call; rewrite using globals: 15/15 pass.

### BUG: Typed function pointer local variables silently break HolyC functions
- **Status:** Confirmed (2026-02-23)
- **Severity:** Medium — silent failure, no error reported
- **Behavior:** Declaring a typed function pointer local variable inside a function body (e.g. `I64 (*fp)(I64 x) = &Fn;` or `U0 (*fp)() = &Fn;`) silently causes the entire function to never execute. The REPL returns `OK`, no exception is thrown, but the function body is never entered.
- **Also affected:** `I64 fp = &Fn; (*fp)(args);` — storing a function address as a plain I64 local and then dereferencing to call also fails silently.
- **What DOES work:** Declare function pointer variables at global scope (`I64 (*g_fp)(I64 x) = 0;`), then assign and call them from inside functions.
- **Workaround:** Move all typed function pointer variables to global scope. Local `I64 fp = &Fn;` (assign only, no call) is safe but the call via local I64 does not work.
- **Evidence:** TestFnPtr.HC — first version with local fp vars produced no results file; rewrite using global fp vars: 12/12 pass.

### Ternary operator `?:` unreliable with pointer/comparison conditions
- **Status:** Confirmed (2026-02-22)
- **Detail:** `p != 0 ? "PASS" : "FAIL"` causes a silent exception in HolyC compiled files. Integer ternary (`1 ? 42 : 0`) also fails in exec_str context. Root cause unknown — may be related to `?` being a help operator in TempleOS's interactive mode interfering with compilation.
- **Workaround:** Always use `if/else` to assign a status variable, then use the variable in StrPrint. Never use inline ternary in TempleOS-side test code.

### HolyC local variables do NOT truncate on assignment
- **Status:** Confirmed (2026-02-22)
- **Detail:** `U8 x; x = 0x1FF;` — x holds 511, not 255. `U8 x; x = 256;` — x holds 256, not 0. All local variables are 64-bit register values; the declared type (U8/U16/U32/I8/I16/I32) does NOT enforce truncation on assignment.
- **Contrast:** Struct fields DO use proper byte-width storage (memory layout is respected). For locals, the type affects pointer arithmetic and zero/sign-extension when loading into I64, but not the stored value.
- **Evidence:** `U8 u8val = 0x1FF;` → `u8val == 511` (not 255). `u8val = 0xFF; r = u8val;` → `r == 255` (zero-extended correctly).
- **Implication:** Never rely on U8/U16/U32 local variable declarations to clamp values. Use explicit masking if needed: `x = val & 0xFF;`.

### F64 NaN comparisons are non-IEEE (x87 behavior)
- **Status:** Confirmed (2026-02-23)
- **Detail:** `NaN == NaN` → `1` (TRUE). `NaN < 1.0` → `1` (TRUE). Per IEEE 754, all NaN comparisons should return false. TempleOS x87 FPU comparisons treat NaN as a normal bit pattern rather than using the IEEE unordered result.
- **Impact:** Code checking `if (x == x)` as an IsNaN test will not work — it returns true even for NaN.

### 0.1 + 0.2 == 0.3 in TempleOS (x87 80-bit extended precision)
- **Status:** Confirmed (2026-02-23)
- **Detail:** `0.1 + 0.2 == 0.3` evaluates to TRUE in TempleOS. In standard IEEE 754 double precision (C, Python), this is FALSE due to rounding. TempleOS uses the x87 FPU in 80-bit extended precision mode, which provides enough extra precision that the accumulated rounding error happens to cancel out for this specific case.
- **Impact:** Floating-point code ported from other languages should not assume IEEE 754 double precision rounding behavior.

### No StrCat in HolyC — use CatPrint
- **Status:** Confirmed
- **Detail:** `StrCat` does not exist in TempleOS. `CatPrint(dst, "%s", src)` is the correct replacement. It modifies `dst` in-place and returns a pointer to `dst`.

### Global variables are NOT zero-initialized
- **Status:** Confirmed (2026-02-22)
- **Detail:** An uninitialized global holds whatever is in memory at startup — observed value was `3421769` (garbage). Unlike C where globals are guaranteed zero-initialized, HolyC does not zero globals. Always provide an explicit initializer: `I64 g_counter = 0;`
- **Impact:** Any global used as a counter, flag, or accumulator without explicit init will start with garbage. Silent bugs if you assume zero.

### StrPrint `%-N` left-justify flag is non-functional
- **Status:** Confirmed (2026-02-22)
- **Detail:** `%-5d` behaves identically to `%5d` — always right-aligns, ignoring the `-` flag. The flag `PRTF_LEFT_JUSTIFY` exists in the source but the implementation does not honour it for integer formats.
- **Workaround:** Implement manual left-padding if needed.

### StrPrint `%g` behaves unexpectedly
- **Status:** Confirmed (2026-02-22)
- **Detail:** `%g` applied to `12345.0` produced `       12345` — a right-padded field, not a general float like C's `%g`. Likely internally maps to a different formatting path. Avoid `%g` — use `%.Nf` or `%e` instead.

### StrPrint `%e` differs from C standard
- **Status:** Confirmed (2026-02-22)
- **Detail:** `%e` of `12345.0` produces `1.23450000e4`, not `1.23450000e+04`. No `+` sign in the exponent, and no leading zero (e.g. `e4` not `e04`). Code parsing `%e` output that expects C-standard format will break.

### StrPrint `%n` engineering notation requires extra args
- **Status:** Confirmed (2026-02-22)
- **Detail:** `%n` of `1500.0` produced `1.50000000e3` — same as `%e`, no SI prefix (e.g. no `1.5K`). The SI prefix feature appears to require auxiliary format arguments not yet understood. Do not use `%n` expecting automatic SI prefixes.

---

## DateTime / Clock

### Struct2Date panics when called from JIT-compiled test code
- **Status:** Confirmed (2026-02-23)
- **Severity:** Medium — safe to call from kernel-compiled code only
- **Behavior:** `Struct2Date(&ds)` called from a dynamically-compiled `#include` context (REPL / TestRunner) causes an OS panic. No exception is thrown — the entire TestRunner task dies before `FileWrite` runs, leaving the previous results file untouched.
- **What works:** `Now()` calls `Struct2Date` internally and works fine. The issue is specific to calling it directly from JIT-compiled code.
- **Workaround:** Use `Now()` to get the current CDate. Avoid calling `Struct2Date` directly in test/REPL code.
- **Source:** `Kernel/KDate.HC`

### NowDateTimeStruct panics when called from JIT-compiled test code
- **Status:** Confirmed (2026-02-23)
- **Severity:** Medium — same context restriction as Struct2Date
- **Behavior:** `NowDateTimeStruct(&ds)` called from JIT-compiled code panics the OS, identical crash pattern to Struct2Date. Even with a heap-allocated `CDateStruct` (`MAlloc(64)`) the crash still occurs.
- **What works:** `Now()` calls `NowDateTimeStruct` internally without issue.
- **Root cause hypothesis:** Both functions may contain inline assembly or use hardware port I/O (`0x70/0x71` RTC registers) in a way that is incompatible with the JIT-compiled calling context. Alternatively, they may clobber registers that the JIT compiler expects to be preserved.
- **Workaround:** Call `Now()` + `Date2Struct()` instead. `Date2Struct` works fine from JIT context.
- **Source:** `Kernel/KDate.HC`

### SerDir.HC: "missing ) at U0" parse error on load
- **Status:** Fixed (2026-02-23)
- **Root cause:** Two implicit integer-to-pointer conversions: `UartPrint(d[3])` passed `I64` where `U8 *` was expected, and `d=d[0]` assigned `I64` to `I64 *`. HolyC's JIT emits "missing ) at U0" for these mismatches.
- **Fix:** Added explicit HolyC casts — `d[3](U8*)` and `d[0](I64*)`. `FilesFind` return also cast explicitly: `FilesFind(path)(I64*)`.
- **Verified:** Fixed version compiles silently (send_cmd returns `OK` with no error) and correctly lists directory entries.

### Str2I64: `0o` octal prefix is NOT supported
- **Status:** Confirmed (2026-02-23)
- **Detail:** `Str2I64("0o17")` returns `0`, not `15`. The `0o` prefix for octal is not recognized. The `0x` (hex) and `0b` (binary) prefixes work correctly.
- **Workaround:** Use explicit radix parameter: `Str2I64("17", 8)` → 15.

### Str2F64 exponential: exact `==` comparison unreliable
- **Status:** Confirmed (2026-02-23)
- **Detail:** `Str2F64("1.5e3") == 1500.0` evaluates to FALSE even though `%.0f` of the result prints `1500`. The x87 extended precision arithmetic used internally by Str2F64 may produce a value infinitesimally different from the 64-bit literal `1500.0`.
- **Workaround:** Use a range check: `g_f > 1499.0 && g_f < 1501.0`. Exact equality only works reliably for values that are exactly representable (e.g. `Str2F64("-2.5") == -2.5` passes).

### StrScan returns pointer to end of full input string, not stop position
- **Status:** Confirmed (2026-02-23)
- **Detail:** `U8 *end = StrScan("99rest", "%d", &i)` — `i` = 99 correctly, but `*end` = 0 (null terminator). StrScan returns a pointer to the end of the entire input string, not the position where matching stopped. This differs from C's `sscanf` which leaves the source pointer unmodified.
- **Contrast:** `Str2I64("123abc", 10, &end)` DOES set `*end` to `'a'` — the stop position. Use Str2I64 with end_ptr when you need to know where parsing stopped.

### DeathWait does NOT null the task pointer
- **Status:** Confirmed (2026-02-23)
- **Detail:** `DeathWait(&task)` documentation implies it sets `*_task = NULL` on return. In practice, the task pointer is unchanged — it still holds the original `CTask *` address after the call returns. Do not rely on the pointer becoming NULL as a "task is dead" indicator.
- **Workaround:** Track task liveness with a separate flag if needed, or call `TaskValidate(task)` — it returns 0 for a dead/invalid task.

### MStrPrint: caller must Free() the returned string
- **Status:** Confirmed (2026-02-23)
- **Detail:** `MStrPrint(fmt, ...)` allocates a new string via MAlloc and returns a pointer to it. The caller owns the memory and must call `Free(s)` when done. Failing to free leaks heap memory permanently (TempleOS has no GC).
- **Pattern:** `U8 *s = MStrPrint("v=%d", val); ... Free(s);`

### StrPrint `%f` shows no decimal places by default
- **Status:** Confirmed (2026-02-23)
- **Severity:** Low — only affects format string output
- **Behavior:** `%f` with no precision specifier rounds to integer (`3.14` → `3`, `0.05` → `0`). Use `%.2f`, `%.4f`, etc. to get decimal places.
- **Evidence:** `ts_advances` delta of ~0.05s printed as `delta=0` with `%f`.
- **Workaround:** Always specify precision: `%.3f` for millisecond-level F64 values.
