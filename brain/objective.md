# Objective

## What We Are Building

A serial interface layer that gives an AI (Claude) full programmatic control over a live TempleOS instance running in QEMU. The goal is to turn TempleOS into an AI-operated computing environment — where Claude can read, write, execute, and reason about everything on the system autonomously.

---

## Why TempleOS

TempleOS is a minimal, single-address-space OS with no networking, no permissions, no abstractions. Everything is accessible directly — memory, hardware, source code, compiled output. This makes it an ideal substrate for AI control:

- No security model to navigate
- All source is available and readable (HolyC, decompressed via FileRead)
- The compiler is built-in — code written to disk can be compiled and executed immediately
- The entire OS fits in a known, reproducible state (QEMU snapshots)

---

## Current State

A serial protocol (CAFEBABE) connects the host (Linux/Claude) to TempleOS over a QEMU virtual serial port. Seven primitives are implemented and deployed:

| Primitive      | Function                                      |
|----------------|-----------------------------------------------|
| SerFileRead    | Read any file from TempleOS to host           |
| SerDir         | List directory contents                        |
| SerFileWrite   | Write arbitrary bytes from host to TempleOS   |
| SerFileExists  | Check if a file exists                         |
| SerMkDir       | Create a directory                             |
| SerExecI64     | Execute HolyC, return integer result           |
| SerExecStr     | Execute HolyC, capture string output           |

The full TempleOS source tree has been mirrored locally (`brain/real-temple-tree/`) and is readable. A Python library (`serial/temple.py`) wraps all primitives into a clean API.

---

## Long-Term Vision

Use TempleOS as a foundation for an AI-native operating system:

- Claude reads kernel source to understand the system deeply
- Claude writes and deploys new HolyC code to extend system capabilities
- Claude executes arbitrary computations on TempleOS and retrieves results
- TempleOS becomes a controlled, inspectable compute substrate
- Potential future directions: persistent AI memory stored on TempleOS filesystem, AI-written drivers, AI-composed music/graphics via the built-in APIs

---

## Guiding Constraints

- All changes to TempleOS are made through the serial primitives — no sendkey hacks for runtime operations
- Every file deployed to TempleOS is kept in sync in `brain/templerepo/`
- `snap1` is always the latest known-good QEMU state — save after every confirmed working milestone
- Keep primitives small and composable — complexity lives on the host side (Python), not in TempleOS
