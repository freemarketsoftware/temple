# Claude ↔ TempleOS Communication Interface

Two channels: **serial** (bootstrap, file I/O, test deployment) and **TCP** (AgentLoop — interactive HolyC execution).

---

## Serial Channel

### Protocol: CAFEBABE terminator
```
\x04\xCA\xFE\xBA\xBE\x04\xFA\xCE
```
Every primitive and SerReplExe's `OK` response both end with this 8-byte sequence.

**Why CAFEBABE?** Mixed-byte sequence — statistically impossible in TempleOS source, compressed HolyC, or binary data. Earlier terminators failed:
- `\x04` — appears in any compressed binary
- `\x04`×3 and ×8 — found in `HomeWrappers.HC.Z`

### Double-response per command
Every command produces **two CAFEBABE sequences**:
1. The primitive's payload + CAFEBABE
2. SerReplExe's `OK` + CAFEBABE

Always drain both. Conditional drain causes desync when both arrive in the same `recv()` chunk.

```python
TERM = b'\x04\xCA\xFE\xBA\xBE\x04\xFA\xCE'

def send_cmd(s, cmd, timeout=20):
    s.sendall((cmd + '\n').encode())
    content, _ = recv_until_term(s, timeout)   # primitive payload
    recv_until_term(s, timeout=10)              # always drain OK
    return content
```

### Setup
```python
from serial.temple import Temple

with Temple() as t:
    t.freeze()                                     # loads SerReplExe + all primitives
    files = t.list_dir("C:/Home/*")
    content = t.read_file("C:/Home/SerProto.HC")
    t.write_file("C:/Home/foo.HC", b'UartPrint("hello\n");')
    t.unfreeze()
```

`t.freeze()` loads SerReplExe via sendkey, then `#include`s all serial primitives.
`t.is_frozen()` sends `;` and checks for CAFEBABE — detects if SerReplExe is active.

---

## Serial Primitives

All primitives loaded by `Temple.freeze()` via `#include "C:/Home/SerXxx.HC";`.

| Primitive     | File                     | Python method        |
|---------------|--------------------------|----------------------|
| SerFileRead   | C:/Home/SerFileRead.HC   | `t.read_file()`      |
| SerDir        | C:/Home/SerDir.HC        | `t.list_dir()`       |
| SerFileWrite  | C:/Home/SerFileWrite.HC  | `t.write_file()`     |
| SerFileExists | C:/Home/SerFileExists.HC | `t.file_exists()`    |
| SerMkDir      | C:/Home/SerMkDir.HC      | `t.mkdir()`          |
| SerExecI64    | C:/Home/SerExecI64.HC    | `t.exec_i64()`       |
| SerExecStr    | C:/Home/SerExecStr.HC    | `t.exec_str()`       |
| SerSymExists  | C:/Home/SerSymExists.HC  | `t.symbol_exists()`  |
| SerSymList    | C:/Home/SerSymList.HC    | `t.list_symbols()`   |
| SerMemInfo    | C:/Home/SerMemInfo.HC    | `t.mem_info()`       |

**SerExecStr design note:** `GStrReset()` and `GStrAdd()` do not emit CAFEBABE. Always combine into one command:
```
GStrReset();{user code}SerSendStr();
```
`t.exec_str(code)` does this automatically. Combined command must fit in SerReplExe's 256-byte buffer.

**File ban list:** See `brain/file-ban.md` — these decompress to multi-MB payloads:
- `C:/Adam/AutoComplete/ACDefs.DATA`
- `C:/Adam/AutoComplete/ACWords.DATA.Z`
- `C:/Misc/Bible.TXT.Z`

---

## TCP Channel (AgentLoop)

AgentLoop.HC runs inside TempleOS, polls `GET /cmd`, executes HolyC via ExeFile, POSTs output to `/result`.

```python
from serial.agent import Agent

with Agent() as ag:
    ag.start()                              # loadvm snap1, deploy, wait online
    result = ag.run('StrPrint(g_agent_out, "%lld\n", 6*7);')  # → "42"
    ag.define('I64 Sq(I64 x) { return x*x; }')
    print(ag.eval_i64('Sq(9)'))             # → 81
    print(f'uptime {ag.uptime():.1f}s')
```

### Key constraints
- `g_agent_out` buffer: 1300 bytes — output per command must fit
- Serial REPL is **blocked** while AgentLoop runs — use `ag.stop()` before any `ag.read_file()` calls
- `pre_deploy` callback in `ag.start()` — runs against serial REPL before AgentLoop launches, use for file deployment

### Agent methods
| Method | Notes |
|--------|-------|
| `ag.start(timeout, pre_deploy)` | Full lifecycle: loadvm + deploy + wait online |
| `ag.run(code, timeout)` | Execute HolyC, return output string |
| `ag.define(code)` | Load definitions (output discarded) |
| `ag.eval_i64(expr)` | Evaluate I64 expression → Python int |
| `ag.eval_f64(expr)` | Evaluate F64 expression → Python float |
| `ag.uptime()` | Seconds since boot |
| `ag.task_list()` | Walk task ring via Fs, return list of task names |
| `ag.read_file(path)` | Read via serial — call ag.stop() first |
| `ag.write_file(path, data)` | Write via serial — use pre_deploy, not post-start |
| `ag.stop()` | Send EXIT, free serial REPL |
