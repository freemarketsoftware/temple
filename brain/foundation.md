# Foundation

Three priority layers toward autonomous AI operation on TempleOS.

---

## 1. Foundation Stability

**Crash recovery**
When Claude writes and runs HolyC autonomously, code will crash TempleOS. Right now that requires manual intervention. Need: detect a crash (socket goes silent), automatically `loadvm snap1`, re-freeze, resume. Without this, autonomous operation is too fragile.

**Larger execution buffer** ✅ (resolved by design)
SerReplExe's buffer was increased from 256 to 4096 bytes. However, investigation revealed the real bottleneck is TempleOS's lexer: hard 255-byte limit per line of compiled code, unfixable without patching the kernel. `exec_str` is therefore best suited for short expressions only. For any real program the correct path is `write_file` + `ExeFile` — write multi-line `.HC` to disk, then execute it. This already works with no size cap and is the intended approach for the code generation pipeline.

**Exception capture** ✅
`SerReplExe.HC` wraps `ExeFile` in `try/catch` with `Fs->catch_except=TRUE` to actually accept the exception. On catch: sends `EXCEPT:<code>` over serial, then `SerSendOk`. Python side raises `TempleException` on both the `EXCEPT:` path and the `b'OK'`-only path (when `SerSendStr` never ran). REPL survives both software throws and hardware faults (div-by-zero). Compiler error text is not yet capturable — goes to screen via TempleOS `Put()`, not UART.

---

## 2. Richer Introspection

**Symbol awareness** ✅
`SerSymExists.HC` — point query: `t.symbol_exists("Foo")` → True/False. Uses `HashFind(name, Fs->hash_table, HTT_FUN|HTT_GLBL_VAR|HTT_CLASS)` which walks the full hash table chain (task → parent → Adam).
`SerSymList.HC` — bulk dump: `t.list_symbols('functions')` → list of names. Walks the full chain manually, streams names over UART. Returns 2262 functions and 245 globals on a standard frozen session.

**Structured output** ✅
Convention: TSV (`\t`-separated fields, `\n`-separated rows). HolyC side uses `GStrAdd` with formatted lines; Python side uses `exec_rows(code)` → list of lists, `exec_kv(code)` → dict.
`SerMemInfo.HC` — concrete example: returns `code_used`, `code_total`, `heap_limit` as TSV. `t.mem_info()` returns `{'code_used': 159MB, 'code_total': 510MB, ...}`.
`SerSymList.HC` updated to emit `name\tkind` (fun/glbl/class) per row. `t.list_symbols(detailed=True)` returns `[(name, kind), ...]`. Note: `\n` in Python strings is a literal newline byte — use raw strings (`r'...'`) when embedding HolyC escape sequences in exec_str calls.

---

## 3. Autonomous Operation

**Self-contained session management**
Claude should be able to freeze, work, unfreeze, and save snap1 entirely on its own without user confirmation at each step.

**Persistent AI workspace**
A directory on TempleOS (`C:/AI/`) where Claude stores its own notes, generated code, results, and state between sessions. The filesystem as Claude's long-term memory.

**Code generation pipeline**
Write HolyC → deploy → load → execute → capture result → iterate. Make this a reliable, fast loop so Claude can actually develop software on TempleOS autonomously.

---

## Status

| Item                      | Layer | Status  |
|---------------------------|-------|---------|
| Crash recovery            | 1     | ✅ done  |
| Larger execution buffer   | 1     | ✅ done  |
| Exception capture         | 1     | ✅ done  |
| Symbol awareness          | 2     | ✅ done  |
| Structured output         | 2     | ✅ done  |
| Session management        | 3     | pending |
| Persistent AI workspace   | 3     | pending |
| Code generation pipeline  | 3     | pending |
