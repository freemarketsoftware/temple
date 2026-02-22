# HolyC Syntax Rules

## Types
- `U0` — void
- `U8` — unsigned 8-bit (byte / char)
- `U16` — unsigned 16-bit
- `U32` — unsigned 32-bit
- `U64` — unsigned 64-bit
- `I8`, `I16`, `I32`, `I64` — signed equivalents
- `Bool` — boolean (0 or 1)
- `F64` — 64-bit float

## Functions
```c
U0 FuncName(U8 *arg1, I64 arg2) {
  // body
}
```
- No return type means `U0` (void)
- Pointers use `*` as in C

## Control Flow
- `if`, `else`, `while`, `for`, `switch/case/break` — same as C
- `switch` works on integers; `case` values must be constants

## I/O (HW ports)
- `OutU8(port, val)` — write byte to I/O port
- `InU8(port)` — read byte from I/O port

## Operators
- Standard C operators apply: `&`, `|`, `>>`, `<<`, `++`, `--`, etc.
- `!` must be escaped as `\!` — e.g. `while(\!UartTxReady());` and `\!=` for not-equal
- Unescaped `!` will cause a compilation error

## String / Memory
- Strings are null-terminated `U8 *`
- `StrCpy(dst, src)`, `MemSet(ptr, val, size)` — standard builtins

## Execution
- Double semicolon `;;` executes the current line immediately in the REPL
- `#include "path"` — includes and compiles a file
- `#include "path";;` — includes and immediately executes in REPL

## Ed (file editor)
- `Ed("C:/Home/file.HC");` — opens file in blocking mode (semicolon is required)
- Without the semicolon Ed opens non-blocking in a side panel — sendkey input goes to the wrong window

## File Paths
- TempleOS uses `C:/` as the primary drive prefix
- Home directory is `C:/Home/`
- Paths use forward slashes

## Printing
- `"%d\n", value;` — printf-style, no explicit print function needed
- `"literal string\n";` — prints directly

## Misc
- No header guards needed
- No namespaces
- No classes (structs only)
- `Bool` returns are `0` or `1`; any nonzero is truthy
