# Primitives Development

Functions giving Claude visibility and control over TempleOS state over serial.
All primitives use the CAFEBABE terminator: `\x04\xCA\xFE\xBA\xBE\x04\xFA\xCE`

---

## Status

| Primitive        | File                    | Status    |
|------------------|-------------------------|-----------|
| SerFileRead      | C:/Home/SerFileRead.HC  | ✅ Done   |
| SerDir           | C:/Home/SerDir.HC       | ✅ Done   |
| SerFileWrite     | C:/Home/SerFileWrite.HC | ✅ Done   |
| SerFileExists    | C:/Home/SerFileExists.HC| ✅ Done   |
| SerMkDir         | C:/Home/SerMkDir.HC     | ✅ Done   |
| SerExecI64       | C:/Home/SerExecI64.HC   | ✅ Done   |
| SerExecStr       | C:/Home/SerExecStr.HC   | ✅ Done   |

---

## SerFileRead ✅
Read a file's contents and send over serial.
- Terminates with CAFEBABE
- TempleOS auto-decompresses `.HC.Z` files on FileRead

## SerDir ✅
List directory entries matching a wildcard pattern.
- Returns newline-separated full paths
- Terminates with CAFEBABE
- Must use `*` wildcard e.g. `"C:/Home/*"`

## SerFileWrite ✅
Write arbitrary bytes from host to TempleOS.
- Ready signal: single `\x04`
- Confirmation: `OK` + CAFEBABE
- Max 65536 bytes per call

## SerFileExists ✅
Check if a file exists. Returns `1` or `0` + CAFEBABE.
- Uses `FileRead` — also returns `1` for directories (TempleOS can read dir entries as bytes)
- Python: `t.file_exists(path)` → True/False

## SerMkDir ✅
Create a directory using DirMk.
- Python: `t.mkdir(path)`
- Verify creation with `t.list_dir(parent + '/*')` not `file_exists` (DirMk result not detectable via FileRead)

## SerExecI64 ✅
Execute HolyC expression, return I64 result as decimal string.
- Declares global `I64 g_r=0;` and `SerGetI64(n)` helper
- Python: `t.exec_i64(expr)` → int
- Two steps internally: `g_r=expr;` then `SerGetI64(g_r);`

## SerExecStr ✅
Capture string output from HolyC execution and send over serial.
- Declares `U8 g_str[4096]`, `I64 g_str_len`
- Helpers: `GStrReset()`, `GStrAdd(s)`, `SerSendStr()`
- Python: `t.exec_str(code)` → str
- Code populates `g_str` via `GStrAdd("...")` or `StrPrint(g_str, fmt, ...)`

### Critical design note — single command pattern
`GStrReset()` and `GStrAdd()` do NOT emit CAFEBABE. Calling them via separate
`exec()` calls causes drain desync (10-second timeout per call waiting for a
CAFEBABE that never comes). Always combine into one `send_cmd`:
```
GStrReset();{user code}SerSendStr();
```
Python's `exec_str(code)` does this automatically. The combined command must
fit in SerReplExe's 256-byte buffer.

---

## Notes
- All primitives loaded via `#include "C:/Home/SerXxx.HC";` through SerReplExe
- Host library: `serial/temple.py` — import Temple class for all operations
- File transfer ban list: `brain/file-ban.md`
- `is_frozen()` method detects if SerReplExe REPL is active (sends `;` no-op, checks for CAFEBABE)
