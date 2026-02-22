# Weird TempleOS Behaviors

## 1. Print output doesn't appear until the next command runs

**Observed:** Running `#include "C:/Home/TestEd.HC"` (which contains `Print("Hello World\n");`)
returned to the `C:/Home>` prompt with no visible output.
"Hello World" only appeared on screen **after** the next command (`Dir;`) was executed.

**Reproduction steps:**
1. Create a script with `Print("Hello World\n");`
2. Run it: `#include "C:/Home/script.HC"`
3. Output is NOT visible yet — prompt returns immediately
4. Run any next command (e.g. `Dir;`)
5. Output NOW appears above the next command's output

**Likely cause:** TempleOS's terminal output is document-based, not stream-based.
`Print` writes into a document buffer. The buffer is only flushed/redrawn to the
screen when the terminal gets a chance to repaint — which happens when the next
interactive command triggers a UI update cycle.

**Workaround:** None needed in practice — output always appears eventually.
For scripting purposes, be aware output may lag behind execution.

---

## 2. `\"` escape does not work in the HolyC REPL

**Observed:** Typing `FileWrite("file.HC","Print(\"Hello\");",13);` at the shell
causes a parse error: `ERROR: Compiler: Expecting ';' at "Hello"`.

**Cause:** The HolyC interactive shell parses input at the token level as you type.
The `"` character always terminates a string — the preceding `\` is not treated as
an escape at the REPL input level.

**Workaround:** Use `Ed("file.HC")` to write files with embedded quotes — the
editor stores characters literally with no parsing. Or build strings byte-by-byte
using `MAlloc`/`MemCpy` and ASCII values (`34` = `"`).

---

## 3. `Dir;` causes a reboot when the wrong key is used

**Observed:** Early attempts at `Dir;` resulted in a system reboot because
`shift-semicolon` was used instead of `semicolon`, sending `Dir:` to TempleOS.

**Cause:** `Dir:` is a valid HolyC label declaration (like a goto label), not a
function call. This caused an unexpected execution path that crashed/rebooted the OS.

---

## 4. `#include "Once"` causes a full OS reboot if already loaded

**Observed:** Running `#include "Once"` on an already-initialized system triggers
a full OS re-initialization, effectively rebooting the session.

**Cause:** `Once` is TempleOS's global initialization script. Running it twice
re-initializes kernel data structures, which destabilizes the running environment.

---

## 5. Logical NOT is `\!`, not `!`

**Observed:** Using `!` for logical NOT in HolyC code (e.g. `if(!StrCmp(...))`) causes `LexExcept` during compilation.

**Correct syntax:** Use `\!` for logical NOT and `\!=` for not-equal. This is confirmed by the raw bytes of `Uart.HC`:
```c
while(\!UartTxReady());
return (InU8(UART_LSR)&LSR_TX_EMPTY)\!=0;
```

**Cause:** TempleOS HolyC uses `\!` as the logical NOT operator. Bare `!` is not a valid token and causes a lexer exception.

---

## 6. `Cls;` does not exist — use `DocClear(DocPut);`

**Observed:** `Cls;` returns `ERROR: Undefined identifier at ";"`.

**Correct command:** `DocClear(DocPut);` — clears the current terminal document.

**Cause:** TempleOS has no `Cls` function. The terminal is a "document" in
TempleOS's UI model, and `DocClear` operates on documents rather than a
traditional terminal buffer.
