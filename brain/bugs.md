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

---

## Notable Findings

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

### No StrCat in HolyC — use CatPrint
- **Status:** Confirmed
- **Detail:** `StrCat` does not exist in TempleOS. `CatPrint(dst, "%s", src)` is the correct replacement. It modifies `dst` in-place and returns a pointer to `dst`.
