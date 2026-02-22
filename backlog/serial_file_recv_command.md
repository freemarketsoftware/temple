# Backlog: File creation via serial REPL — Option 2: Dedicated RECV command

## Concept
Add a special `RECV:filename` command to the REPL loop. When received, the REPL switches
into raw receive mode: reads bytes until `EOT` (0x04), writes the full content to the
named file in one shot, then resumes the normal command loop.

## Why it's better than Option 1
- No chunking logic needed on either side
- No buf size constraints — reads until EOT regardless of size
- Completely replaces Ed+sendkey scripts
- Host side: just open socket, send `RECV:C:/Home/foo.HC\n`, then stream file bytes + EOT

## Why deferred
Too complex for current stage. We are moving with simpler imperfect approaches first.
Option 1 (chunked FileWrite) is the stepping stone.

## Rough design (SerReplExe side)
```c
if StrCmp prefix "RECV:" {
  filename = buf + 5;
  U8 fbuf[BIG]; I64 sz = 0; U8 ch;
  while((ch = UartGetChar()) != 4) fbuf[sz++] = ch;
  FileWrite(filename, fbuf, sz);
  SerSendOk();
}
```

## Host side
```python
s.sendall(b'RECV:C:/Home/foo.HC\n')
s.sendall(file_content + b'\x04')
# wait for OK
```
