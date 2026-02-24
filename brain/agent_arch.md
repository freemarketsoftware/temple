# Agent Architecture — Living Inside TempleOS

Captured 2026-02-24. Design for replacing the file-deploy/poll-results serial workflow
with a persistent, interactive agent loop.

---

## Current Setup

```
Claude (me)
   │  writes HolyC files
   ▼
Python serial/temple.py  ──── Unix socket ──── QEMU serial ──── TempleOS REPL
   │                                                              (SerReplExe.HC)
   │  deploys file → runs it → polls results file → parses
   ▼
brain/templerepo/TestXxx.HC
```

**Friction points:**

1. **Stateless** — every Python invocation re-loads all REPL modules (~10 `#include` round-trips)
2. **File-based I/O** — code must be written to disk, executed, output written to a results file, then read back; no streaming
3. **No interactive loop** — code written offline, deployed as a unit, can't iterate snippet-by-snippet
4. **Opaque execution** — a long `Sleep()` loop is silent until it finishes

---

## The Opportunity: We Already Have TCP

TempleOS can already:
- Open a TCP connection to `10.0.2.2:8080` (QEMU SLiRP gateway / host) ✅
- Receive a full HTTP response ✅
- Send data as the TCP payload ✅

The only missing primitive is **HTTP POST** (send a body) — a small change to the existing
HTTP GET code (different verb + `Content-Length` header).

---

## Proposed Architecture: TempleOS Agent Loop over HTTP

```
Claude (me)
   │  pushes HolyC snippets
   ▼
Python temple_agent.py    ←── GET /cmd ───  AgentLoop.HC (running in TempleOS)
   HTTP server at :8080       POST /result ──►  (infinite poll loop)
   /cmd  → next queued code                     exec code, collect output
   /result ← stdout/results
```

**How it feels to use:**
- TempleOS boots, `AgentLoop.HC` starts: NIC init, then infinite `GET /cmd` poll
- Push a HolyC snippet from Python (or directly via Claude tool call)
- TempleOS fetches it, executes it via JIT, POSTs output back
- Result arrives immediately — no file deployment, no polling a results file
- **State persists across snippets** — globals and loaded symbols stay between calls
- Serial stays as bootstrap/fallback only

---

## Build Plan

| Piece | Size | Notes |
|-------|------|-------|
| HTTP POST in HolyC | Small | Same TCP code as TestHTTPGet; change verb, add `Content-Length:` header, send body |
| `AgentLoop.HC` | Medium | NIC init → loop: GET /cmd → if non-empty exec → POST /result |
| `temple_agent.py` | Medium | Python HTTP server (`/cmd`, `/result` endpoints) + client API |
| QEMU port-forward | Tiny | Already using `:8080`; confirm `-net user,hostfwd=tcp::8080-:8080` is in launch args (currently implicit via QEMU default NIC) |

---

## Alternative: Serial Persistence Only

Lower effort, no TempleOS changes required.  Keep serial but hold the REPL open across
multiple snippet executions without re-loading modules each time.  Faster iteration, but
still file-based and no streaming.  Good interim step if the agent loop proves complex.

---

## Decision

Go with the HTTP agent loop.  It is a natural extension of the proven TCP stack, eliminates
file-based I/O, gives near-streaming output, and reuses everything already built.
Serial remains the bootstrap and recovery mechanism.

**Next steps (in order):**
1. Implement HTTP POST in HolyC (`TestHTTPPost.HC` — Tier 7 backfill)
2. Write `AgentLoop.HC` (NIC init + GET/exec/POST loop)
3. Write `serial/temple_agent.py` (Python HTTP server + push/read API)
4. Update QEMU launch script if port-forwarding needs to be made explicit
5. Update `test_plan.md` and document the new workflow
