# Foundation

Three priority layers toward autonomous AI operation on TempleOS.

---

## 1. Foundation Stability

**Crash recovery** ✅
When Claude writes and runs HolyC autonomously, code will crash TempleOS. Need: detect a crash (socket goes silent), automatically `loadvm snap1`, re-freeze, resume. Solved via `Temple.recover()` and Agent lifecycle.

**Larger execution buffer** ✅
SerReplExe's buffer was increased to 4096 bytes. The real bottleneck is TempleOS's lexer: hard 255-byte limit per line of compiled code. `exec_str` is best for short expressions. For real programs: `write_file` + `ExeFile` — write multi-line `.HC` to disk, execute it. This works with no size cap and is the intended path for the agent loop.

**Exception capture** ✅
`SerReplExe.HC` wraps `ExeFile` in `try/catch` with `Fs->catch_except=TRUE`. On catch: sends `EXCEPT:<code>` over serial. Python raises `TempleException`. REPL survives both software throws and hardware faults. Compiler error text goes to screen via TempleOS `Put()`, not UART — not capturable, returns `b'OK'`.

AgentLoop.HC also wraps ExeFile in try/catch; writes `EXCEPT\n` to `g_agent_out` on exception.

---

## 2. Richer Introspection

**Symbol awareness** ✅
`SerSymExists.HC` — point query: `t.symbol_exists("Foo")` → True/False.
`SerSymList.HC` — bulk dump: `t.list_symbols('functions')` → list of names. Walks the full hash chain (task → parent → Adam). Returns ~2262 functions and ~245 globals on a frozen session.

**Structured output** ✅
Convention: TSV (`\t`-separated fields, `\n`-separated rows). HolyC side uses `CatPrint` with formatted lines; Python parses via `split('\t')`.
`SerMemInfo.HC` — returns `code_used`, `code_total`, `heap_limit` as TSV.

---

## 3. Autonomous Operation

**Code generation pipeline** ✅
AgentLoop.HC + Agent class: push HolyC snippets from Python via `ag.run()`, get output back. Globals and loaded symbols persist across calls. TCP channel (GET /cmd → POST /result) replaces file-deploy/poll-results workflow. 7/7 agent tests pass.

**Persistent AI workspace** ✅
`C:/AI/` is the AI workspace on TempleOS. Contains `AgentLoop.HC`, `_cmd.HC`, `debug.txt`, `tests/`, `results/`. Persists within a session; snap1 preserves it across sessions.

**Session management** ✅
`Agent.start()` handles the full lifecycle: flush queues, kill/restart agent_server, `loadvm snap1`, deploy AgentLoop via serial, poll PONG until online. `Agent.stop()` sends EXIT and drains serial. `pre_deploy` callback for pre-launch file deployment.

---

## Status

| Item                      | Layer | Status   |
|---------------------------|-------|----------|
| Crash recovery            | 1     | ✅ done  |
| Larger execution buffer   | 1     | ✅ done  |
| Exception capture         | 1     | ✅ done  |
| Symbol awareness          | 2     | ✅ done  |
| Structured output         | 2     | ✅ done  |
| Code generation pipeline  | 3     | ✅ done  |
| Persistent AI workspace   | 3     | ✅ done  |
| Session management        | 3     | ✅ done  |
