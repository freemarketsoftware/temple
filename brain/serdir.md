# SerDir Research Notes

## Goal
Implement `SerDir` — send a directory listing over serial from TempleOS.

## What Works
- `FilesFind("C:/Home/*")` — exists, returns a pointer to a struct (e.g. `0x12D567B0`)
- `Dir("C:/Home/")` — exists, prints listing to console, returns file count (e.g. 14). Not useful for serial output.

## What Does NOT Exist
- `DirFirst` — undefined
- `DirNext` — undefined
- `FilesNext` — undefined
- `MkDir` — undefined (correct name is `DirMk`)

## FilesFind Struct Layout (partial, from manual byte inspection)

| Offset | Size | Content |
|--------|------|---------|
| 0-7    | 8    | Pointer — likely next entry in linked list (e.g. `0x12D734D0`) |
| 8-15   | 8    | 0 (null) |
| 16-23  | 8    | 0 (null) |
| 24-31  | 8    | Pointer to full path string (e.g. `0x12D71838` → `"C:/Home/."`) |
| 32+    | ?    | Zeros so far — not yet explored fully |

### Notes
- Path at offset 24 is the **full path** including drive prefix (e.g. `C:/Home/.`)
- First entry returned is `.` (current directory)
- TempleOS uses **postfix typecasting**: `value(type)` NOT C-style `(type)value`
  - e.g. `d(U8**)` instead of `(U8**)d`
  - Using C-style gives: `"Use TempleOS postfix typecasting at U8"`

## Iteration — SOLVED

- `d[0]` is the next entry pointer — **confirmed**
- Chain terminates with null — **confirmed**
- Full loop pattern (tested in REPL):
```c
I64 *d=FilesFind("C:/Home/*");
while(d){
  Print("%s\n",d[3]);  // path string
  d=d[0];              // next entry
}
```

## Working SerDir Implementation
```c
U0 SerDir(U8 *path){
  I64 *d=FilesFind(path);
  while(d){
    UartPrint(d[3]);
    UartPutChar(10);
    d=d[0];
  }
  UartPutChar(4);
}
```

## Remaining Questions
1. Is there a function to free/release the FilesFind result?
2. Are there other fields (file size, date, flags) and at what offsets?
