# Rules

1. Always use Ed to write test scripts on the TempleOS side. Ed works — must be called with a semicolon: `Ed("C:/Home/file.HC");` — without the semicolon, Ed opens non-blocking in a side panel and sendkey input goes to the wrong window.
2. Always maintain a replica of every file added to TempleOS inside `brain/templerepo/`. Keep it in sync whenever a file is created or modified on the TempleOS side.
3. Save to snap1 (`savevm snap1`) after a feature is successfully implemented and confirmed working. This keeps snap1 as the latest known-good state.
4. Don't go on big debug loops. If something fails, stop, clearly state what failed and why, and ask the user before trying more than one fix attempt.
5. Never delete snap1 (`delvm snap1`). It is the safe restore point and must always exist. Overwriting it with `savevm snap1` is allowed when confident in the new state — but deleting it outright to start from scratch is forbidden.
   Never delete or overwrite `snap_backup` under any circumstances. It is the absolute backup and restored only in catastrophic situations. See `brain/backup/README.md`.
6. When starting an implementation session: send `#include "C:/Home/SerReplExe.HC"` via sendtext.sh, then send `Dir;` to trigger execution, then ask the user to confirm TempleOS is frozen before proceeding.
7. Never use the REPL to define code directly. Always write code to a file first (via Ed + deploy script), then load it with `#include` sent through the REPL. Code defined inline via the REPL is not persistent and harder to debug.
8. Always manually confirm that a TempleOS function exists before using it in any implementation. Test it directly in the TempleOS REPL via sendtext.sh first. Do not trust unverified code from scripts or documentation — only functions confirmed working in the REPL are safe to use.
9. Always send EXIT to unfreeze TempleOS via the serial socket, never via sendtext.sh: `echo -ne 'EXIT\n' | sudo nc -N -U /tmp/temple-serial.sock`
10. Never modify TempleOS kernel files. The kernel (C:/Kernel/, C:/Adam/, C:/Compiler/) is off-limits until we have deep understanding of the system and a clear, justified reason to go there. Work exclusively in C:/Home/ and user space.
11. Before any major modification to TempleOS (new primitive, structural change, anything that touches existing working code), create a named pre-work snapshot via the QEMU monitor:
    `savevm snap_pre_<feature>` — e.g. `snap_pre_execbuf`, `snap_pre_excapture`
    This is separate from snap1. It gives a restore point specific to the work about to begin, so a failed attempt doesn't require rolling back snap1. After the work is confirmed working, snap1 is updated as usual. Pre-work snapshots are kept indefinitely — only clean them up when disk space becomes a concern.
