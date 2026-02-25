# Rules

1. **templerepo sync:** Always maintain `brain/templerepo/` in sync with any file created or modified in `C:/AI/`. This is the source of truth for all TempleOS-side code.

2. **snap1:** The rolling working baseline. Save after major milestones with `savevm snap1`. Never delete it. Overwriting is fine. Save only from a clean state — SerReplExe idle, no AgentLoop running.

3. **Dated backups:** After significant sessions, save a dated snapshot (`snap_YYYYMMDD`) AND push to GitHub. These are permanent — never overwrite a dated snapshot.

4. **No debug marathons:** If something fails, stop, state what failed and why, and ask the user before trying more than one fix attempt.

5. **No kernel modifications:** `C:/Kernel/`, `C:/Adam/`, `C:/Compiler/` are off-limits. Work exclusively in `C:/Home/` and `C:/AI/`.

6. **Tests are HolyC on TempleOS:** Unit test logic lives in `C:/AI/tests/TestXxx.HC`. Tests write TSV results to `C:/AI/results/`. Python orchestrates only (deploy, run, collect). No test logic in Python.

7. **Agent serial conflict:** Once AgentLoop is running, the serial REPL is blocked. File operations via `ag.write_file()` / `ag.read_file()` must happen either via `pre_deploy` (before launch) or after `ag.stop()` (after exit). Never call serial I/O while AgentLoop is live.

8. **Mirror:** Run `sync_mirror.py` and commit `brain/real-temple-tree/` after significant changes to `C:/Home/` on the VM.
