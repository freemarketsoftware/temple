# Claude ↔ TempleOS Communication Interface

Serial-based primitives for Claude to interact with TempleOS programmatically.
All functions send output over UART and terminate with **CAFEBABE** (`\x04\xCA\xFE\xBA\xBE\x04\xFA\xCE`).

## Setup

1. Freeze TempleOS via QEMU sendkey: `#include "C:/Home/SerReplExe.HC"`
2. In Python, use `Temple.freeze()` — loads SerReplExe and all primitives automatically
3. Call primitives via `Temple.send_cmd(...)` or the typed helper methods
4. Use `Temple.unfreeze()` when done

**Python import:**
```python
from serial.temple import Temple

with Temple() as t:
    t.freeze()
    files = t.list_dir("C:/Home/*")
    content = t.read_file("C:/Home/SerProto.HC")
    t.write_file("C:/Home/foo.HC", b'UartPrint("hello\n");')
    t.unfreeze()
```

---

## Protocol

### Terminator: CAFEBABE
```
\x04\xCA\xFE\xBA\xBE\x04\xFA\xCE
```
Every primitive and SerReplExe's `OK` response both end with this 8-byte sequence.

**Why CAFEBABE?** Mixed-byte sequence — statistically impossible to appear in TempleOS source, compressed HolyC, or binary data. Earlier terminators failed:
- `\x04` (single EOT) — appears in any compressed binary
- `\x04\x04\x04` (triple EOT) — found in `HomeWrappers.HC.Z` at byte 12
- `\x04`×8 — also found in `HomeWrappers.HC.Z`

### Double-response per command
Every command through SerReplExe produces **two CAFEBABE sequences**:
1. The primitive's payload + CAFEBABE
2. SerReplExe's `OK` + CAFEBABE

**Always drain both.** Use unconditional drain after every `send_cmd`.

```python
TERM = b'\x04\xCA\xFE\xBA\xBE\x04\xFA\xCE'

def recv_until_term(s, timeout=20):
    buf = b''
    deadline = time.time() + timeout
    s.settimeout(1.0)
    while time.time() < deadline:
        try:
            chunk = s.recv(512)
            if chunk:
                buf += chunk
                if TERM in buf:
                    idx = buf.index(TERM)
                    return buf[:idx], buf[idx + len(TERM):]
        except socket.timeout:
            pass
    return None, b''

def send_cmd(s, cmd, timeout=20):
    s.sendall((cmd + '\n').encode())
    content, _ = recv_until_term(s, timeout)   # primitive payload
    recv_until_term(s, timeout=10)              # always drain OK
    return content
```

**WARNING:** Conditional drain (`if TERM not in remainder`) causes protocol desync when both TERMs arrive in the same `recv()` chunk. Always drain unconditionally.

---

## Primitives

### SerDir
**File:** `C:/Home/SerDir.HC`
**Python:** `t.list_dir(pattern)` → list of paths

List directory entries matching a wildcard pattern.

```
SerDir("C:/Home/*");
```

**Response:** Newline-separated full paths + CAFEBABE. Includes `.` and `..`.

**Notes:**
- Pattern must include `*` wildcard
- Python helper strips `.`, `..`, null bytes, non-path lines

---

### SerFileRead
**File:** `C:/Home/SerFileRead.HC`
**Python:** `t.read_file(path, timeout=30)` → bytes or None

Read a file's raw bytes over serial.

```
SerFileRead("C:/Home/SerProto.HC");
```

**Response:** Raw file bytes + CAFEBABE.

**Notes:**
- TempleOS auto-decompresses `.HC.Z` files — you receive readable HolyC source
- `.DATA` files (DolDoc format) can be multi-MB — see `brain/file-ban.md`
- Returns None on timeout

---

### SerFileWrite
**File:** `C:/Home/SerFileWrite.HC`
**Python:** `t.write_file(path, content: bytes)`

Write arbitrary bytes from host to TempleOS.

```
SerFileWrite("C:/Home/foo.HC");
```

**Protocol:**
1. Send command + `\n`
2. Wait for single `\x04` — ready signal from TempleOS
3. Send file bytes + `\x04`
4. Drain two CAFEBABE sequences (write confirmation + SerReplExe OK)

**Limit:** 65536 bytes per call.

---

### SerFileExists
**File:** `C:/Home/SerFileExists.HC`
**Python:** `t.file_exists(path)` → bool

Check if a file (or directory) exists.

```
SerFileExists("C:/Home/SerReplExe.HC");
```

**Response:** `1` or `0` + CAFEBABE.

**Notes:**
- Uses `FileRead` internally — also returns `1` for directories (TempleOS can read dir entries as raw bytes)
- To check for directories specifically, use `t.list_dir(path + '/*')` and check for entries

---

### SerMkDir
**File:** `C:/Home/SerMkDir.HC`
**Python:** `t.mkdir(path)`

Create a directory on TempleOS using `DirMk`.

```
SerMkDir("C:/Home/MyDir");
```

**Response:** CAFEBABE only (no payload — just confirms execution).

**Notes:**
- Silent success/fail — TempleOS `DirMk` does not return a status
- Verify creation with `t.list_dir(parent + '/*')` — `file_exists` is unreliable for dirs (returns True due to FileRead reading dir entries)

---

## File Ban List

See `brain/file-ban.md` for files excluded from `read_file`. These decompress to multi-MB payloads that timeout:
- `C:/Adam/AutoComplete/ACDefs.DATA`
- `C:/Adam/AutoComplete/ACWords.DATA.Z`
- `C:/Misc/Bible.TXT.Z`

---

## Snapshots

| Name | Saved | Contents |
|------|-------|----------|
| `snap_backup` | First working serial comms | SerReplExe, SerDir, SerFileRead, SerFileWrite |
| `snap_proto_v2` | Triple-EOT milestone | SerProto with `\x04\x04\x04` |
| `snap_cafebabe` | CAFEBABE + validated tree | Full C:/Home+Adam mirror validated |
| `snap1` | Rolling | Current working state |

**Never overwrite `snap_backup`.**

---

## Rules

1. All REPL commands sent via serial socket (`/tmp/temple-serial.sock`), not QEMU sendkey
2. EXIT sent via serial: `echo -ne 'EXIT\n' | sudo nc -N -U /tmp/temple-serial.sock`
3. Always drain unconditionally after every command
4. Never read banned files — check `brain/file-ban.md`
5. Never overwrite `snap_backup`
