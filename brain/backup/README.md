# Backup

## snap_backup — Absolute Backup Snapshot

QEMU snapshot saved after full serial communication layer was confirmed working.

### State at time of backup
- `SerReplExe.HC` — serial REPL with FileWrite+ExeFile execution pipeline
- `SerDir.HC` — directory listing over serial
- `SerFileRead.HC` — file read over serial
- `SerFileWrite.HC` — file write over serial
- Full round-trip read/write verified

### How to restore
```bash
echo "loadvm snap_backup" | sudo nc -N -U /tmp/qmon.sock
```

### Rules
- **Never overwrite or delete `snap_backup`** — it is the absolute restore point
- Use `snap1` for day-to-day save/restore

---

## snap_proto_v2 — Triple-EOT Protocol Snapshot

QEMU snapshot saved after upgrading the serial protocol to use `\x04\x04\x04` triple-EOT terminator.

### State at time of snapshot
- `SerProto.HC` — `SerSend` updated to emit 3 EOTs
- `SerFileRead.HC` — terminates with 3 EOTs
- `SerDir.HC` — terminates with 3 EOTs
- `SerFileWrite.HC` — ready signal still single EOT, OK response via SerSendOk (3 EOTs)
- TempleOS file tree mirror in progress (`brain/real-temple-tree/`)

### How to restore
```bash
echo "loadvm snap_proto_v2" | sudo nc -N -U /tmp/qmon.sock
```

---

## snap_cafebabe — CAFEBABE Terminator + Validated Tree

QEMU snapshot saved after upgrading to the `\x04\xCA\xFE\xBA\xBE\x04\xFA\xCE` mixed-byte terminator and completing a clean mirror of `C:/`, `C:/Home`, and `C:/Adam`.

### State at time of snapshot
- `SerProto.HC` — `SerSend` emits CAFEBABE terminator
- `SerFileRead.HC` — terminates with CAFEBABE
- `SerDir.HC` — terminates with CAFEBABE
- Host drain logic fixed: unconditional double-drain after every command
- `brain/real-temple-tree/` — `C:/`, `C:/Home`, `C:/Adam` fully mirrored and validated
- `brain/file-ban.md` — large files excluded from transfer

### How to restore
```bash
echo "loadvm snap_cafebabe" | sudo nc -N -U /tmp/qmon.sock
```

---

## snap1 (current) — Full tree mirror + SerFileExists + SerMkDir

QEMU snapshot saved after completing the full TempleOS file tree mirror and deploying two new primitives.

### State at time of snapshot
- All previous CAFEBABE protocol state preserved
- `SerFileExists.HC` — deployed and tested ✅
- `SerMkDir.HC` — deployed and tested ✅
- `brain/real-temple-tree/` — complete mirror: C:/, Home, Adam, 0000Boot, Apps, Compiler, Demo, Doc, Kernel, Linux, Misc, Tmp
- `serial/temple.py` — full Python library, `freeze()` loads all 5 primitives automatically
- `brain/file-ban.md` — ACDefs.DATA, ACWords.DATA.Z, Bible.TXT.Z banned
- `brain/comm-interface-claude-temple.md` — fully updated to CAFEBABE protocol
- `SerExecI64.HC` — deployed and tested ✅ (exec_i64, global g_r, SerGetI64)

### How to restore
```bash
echo "loadvm snap1" | sudo nc -N -U /tmp/qmon.sock
```
