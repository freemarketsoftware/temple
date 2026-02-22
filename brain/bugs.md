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

## Notable Findings

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
