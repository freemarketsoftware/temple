# Temple

**An AI-driven, mutable operating system built on TempleOS.**

Temple is an experiment in giving an AI agent full programmatic control over a live OS — reading its source, writing new code, running it, observing results, and iterating. The substrate is TempleOS running inside QEMU. The agent is Claude. The interface is a custom serial protocol.

The goal is not just to automate tasks on TempleOS. The goal is to build toward an OS that can evolve itself under AI guidance: fixing bugs in the kernel, growing new capabilities, and eventually running on bare metal.

---

## Why TempleOS

- **No abstractions.** No networking stack, no permissions model, no package manager. Everything is visible HolyC source.
- **Built-in compiler.** Code can be written and executed in the same session, with results immediately observable.
- **Reproducible state.** QEMU snapshots make every session reversible. Experiments that crash the OS cost nothing.
- **Minimal surface area.** ~100K lines of HolyC. A single agent can hold the entire codebase in context.

---

## Architecture

```
Claude (agent)
    │
    │  Python  serial/temple.py
    ▼
QEMU virtual serial port  (/tmp/temple-serial.sock)
    │
    │  CAFEBABE protocol
    ▼
SerReplExe.HC  (HolyC REPL loop running inside TempleOS)
    │
    ▼
TempleOS kernel + filesystem
```

Every interaction goes through `SerReplExe` — a small HolyC program that loops on the serial port, writes each received command to a temp file, compiles and executes it, catches any exceptions, and sends the result back. The Python library in `serial/temple.py` wraps this into typed methods.

---

## Current State

Seven serial primitives are deployed and working:

| Primitive | What it does |
|-----------|-------------|
| `SerFileRead` | Read a file from TempleOS to host |
| `SerFileWrite` | Write a file from host to TempleOS |
| `SerDir` | List directory contents |
| `SerFileExists` | Check if a path exists |
| `SerMkDir` | Create a directory |
| `SerExecI64` | Execute HolyC, return an I64 result |
| `SerExecStr` | Execute HolyC, capture string output |

A unit test framework runs HolyC test files at `C:/AI/tests/` and reads TSV results from `C:/AI/results/`. 21 test files cover MAlloc, integer math, strings, file I/O, memory operations, type behavior, bit ops, and exception handling.

---

## Repo Layout

```
brain/
  objective.md          — what we are building and why
  longterm.md           — four long-term goals (kernel bugs, HTTP, bare metal, UI)
  foundation.md         — three-layer plan for autonomous operation
  rules.md              — 14 operational rules for safe, reproducible work
  bugs.md               — confirmed kernel bugs and notable findings
  kernel_api.md         — verified TempleOS kernel function reference
  holyc-reference.md    — HolyC language reference
  comm-interface-claude-temple.md — serial protocol and primitive documentation
  templerepo/           — local mirror of every file deployed to C:/Home/
  real-temple-tree/     — full TempleOS source tree (read-only reference)

serial/
  temple.py             — Python library: Temple class, all primitives
  deploy_all.py         — deploy brain/templerepo/ to C:/Home/ after any loadvm
  run_test.py           — run a single HolyC test file, print pass/fail
```

---

## Quick Start (for an AI agent resuming this session)

1. **Check state:** `sudo python3 serial/temple.py` — or call `t.is_frozen()` to confirm the REPL is alive.
2. **If not alive:** Run `deploy_all.py` to restore all files after a snapshot load, then start `SerReplExe`.
3. **Read the rules first:** `brain/rules.md` — 14 rules that keep the session safe and reproducible.
4. **Read current bugs:** `brain/bugs.md` — confirmed kernel bugs and workarounds.
5. **Run a test:** `sudo python3 serial/run_test.py brain/templerepo/TestException.HC`

Key invariant: **`snap1` is always the last known-good state.** Always run `deploy_all.py` after any `loadvm snap1` since disk reverts to snapshot state.

---

## Long-Term Vision

1. **Kernel bug hunting** — Claude reads kernel source, writes targeted tests, documents findings autonomously.
2. **HTTP stack** — e1000 NIC driver → ARP/IP/TCP → HTTP client and server, entirely in HolyC.
3. **Bare metal** — extend from QEMU to real x86-64 hardware: UEFI, ACPI, modern controllers.
4. **UI refresh** — evolve the interface while preserving Terry's keyboard-first design philosophy.

See `brain/longterm.md` for detail.

---

## Protocol

Commands are sent as null-terminated strings over the QEMU virtual serial port. Every response is terminated by the CAFEBABE sequence (`\x04\xCA\xFE\xBA\xBE\x04\xFA\xCE`). Each command produces two CAFEBABE-delimited responses: the primitive's payload, then `OK` from SerReplExe. Exceptions are returned as `EXCEPT:<name>` in place of the payload.

See `brain/comm-interface-claude-temple.md` for the full protocol spec.
