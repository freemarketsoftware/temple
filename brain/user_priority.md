# User Priorities

## Active

### ~~Find the correct TempleOS string-execution function~~ ✓ DONE
- **Result:** FileWrite+ExeFile workaround implemented in `SerReplExe.HC`. Confirmed working — `UartPrint("EXEC_OK\n");` sent over serial, `EXEC_OK` received back. Pipeline fully validated.

### File creation via serial REPL — Option 1: Chunked FileWrite
- **Context:** The REPL (SerReplExe) can execute arbitrary HolyC, making it a better communication layer than sendkey. Goal: use it to write full `.HC` files to TempleOS, replacing the Ed+sendkey scripts entirely.
- **Approach:** Send `FileWrite` commands in chunks over the REPL. Each command appends a chunk to the target file. Once all chunks are sent, the file is complete on TempleOS disk.
- **Requirements:**
  - Increase `buf` size in SerReplExe beyond 256 bytes to fit chunked write commands
  - Confirm TempleOS has `FileWriteAppend` (or equivalent) for multi-chunk writes
  - Host-side script splits the source file into chunks and sends them sequentially
- **Stop + save flow:** Send `EXIT\n` to unfreeze TempleOS → `savevm snap1` via QEMU monitor
- **Next step:** Investigate `FileWriteAppend` availability in TempleOS; design chunk size and host-side sender script.

### [Sub] ~~Validate serial receive pipeline with console echo~~ ✓ DONE
- **Result:** Serial receive + OK response confirmed working. Two consecutive PASS. Console print side frozen (acceptable). Pipeline is solid.
