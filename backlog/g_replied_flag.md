# Backlog: g_replied double-response guard

## What it is
A global flag used in SerRepl.HC to prevent sending two serial responses for a single command.

## Why it matters
The REPL loop always sends `OK\x04` at the end of each iteration.
If the *executed code* itself calls `SerSend()` (e.g. to return a result), the host would
receive two responses — breaking the protocol.

The flag short-circuits the default OK:
```c
U8 g_replied=0;
U0 SerSend(U8 *s){UartPrint(s);UartPutChar(4);g_replied=1;}  // sets flag
...
loop:
  g_replied=0;
  // execute command...
  if(\!g_replied)SerSendOk();  // only fires if executed code didn't call SerSend
```

## Why it was dropped (for now)
`SerProto.HC`'s `SerSend` does not set `g_replied`. Re-adding it requires redefining
`SerSend` after the include. Deferred because at current validation stage, no executed
command will call `SerSend` directly.

## How to restore it
After `#include "C:/Home/SerProto.HC"`, redefine SerSend:
```c
U8 g_replied=0;
U0 SerSend(U8 *s){UartPrint(s);UartPutChar(4);g_replied=1;}
```
HolyC allows function redefinition — the later definition wins.
Then restore `g_replied=0;` reset and `if(\!g_replied)SerSendOk();` in the loop.
