# Bug List

Active issues and known problems to investigate.

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
