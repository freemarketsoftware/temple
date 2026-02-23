# Bug List

Active issues, known problems, and notable findings to investigate.

---

## Primitives

### SerSymList - not deployed after snapshot load
- **Status:** Missing on TempleOS filesystem
- **Cause:** `loadvm snap_pre_pipeline` (or any snapshot load) reverts the qcow2 disk to the snapshot's state. Files deployed to TempleOS after the snapshot was taken are LOST. SerSymList.HC was deployed after snap_pre_pipeline was saved.
- **Fix:** Redeploy all brain/templerepo/ files via `serial/deploy_all.py` after any loadvm.

### SerMemInfo - not deployed after snapshot load
- **Status:** Missing on TempleOS filesystem
- **Cause:** Same as above — deployed after snap_pre_pipeline, lost on loadvm.
- **Fix:** Same redeployment as above.

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

### FileWrite returns a disk sector index, not byte count
- **Status:** Confirmed (2026-02-22)
- **Detail:** `FileWrite(path, buf, size)` returns an I64 that increments by 2 on each call, regardless of content size. This is a disk sector/block allocation index, not the number of bytes written. The function succeeds and content is correct — only the return value is misleading.
- **Evidence:** Called 4 times with sizes 3, 3, 5, 1 — returned 23129, 23131, 23133, 23135 (always +2).
- **Implication:** Do not use FileWrite's return value to verify write success. Use FileRead + MemCmp instead.

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

### No StrCat in HolyC — use CatPrint
- **Status:** Confirmed
- **Detail:** `StrCat` does not exist in TempleOS. `CatPrint(dst, "%s", src)` is the correct replacement. It modifies `dst` in-place and returns a pointer to `dst`.
