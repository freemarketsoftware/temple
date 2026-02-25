# Long-Term Goals

These are the ideals this project is working toward. They are not sprint items —
they are the reason the foundation exists.

---

## 1. Kernel Bug Hunting

TempleOS's kernel is ~100K lines of HolyC, written by one person, never
systematically tested. There are almost certainly edge cases, memory issues,
and undefined behaviors that have never been found because no one built
tooling to look.

**The approach:** Claude reads the kernel source (already mirrored in
`brain/real-temple-tree/`), identifies suspicious patterns, writes targeted
HolyC test cases, runs them through the Agent pipeline, and documents findings.
The foundation is now solid enough to start this work.

**Why it matters:** Any serious work on TempleOS (networking, UI, bare metal)
will touch the kernel. Understanding its failure modes first is essential.

**Early findings:** Already documented in `bugs.md` — UAF is silent, double-free panics, MAlloc OOMs panic, CeilI64 wrong for negatives, F64 locals crash functions, typed fp locals break functions, `continue` unsupported, block-scoped vars panic.

---

## 2. HTTP Stack

TempleOS has no networking by design. QEMU emulates an e1000 NIC.

**Status: substantially built.** The full client-side stack is working:

```
e1000 NIC driver ✅ → ARP ✅ → IP ✅ → TCP ✅ → HTTP client ✅ → AgentLoop ✅
```

- e1000 init, TX, RX: confirmed working (Tier 5 tests, all pass)
- ARP, IPv4 checksum, TCP, ICMP, UDP: confirmed working (Tier 6 tests)
- HTTP GET + POST: working (Tier 7 tests, AgentLoop)
- AgentLoop: persistent GET/cmd → ExeFile → POST/result loop, 7/7 pass

**Remaining:** HTTP server (serving from TempleOS), UDP-based services, persistent TCP connections to avoid per-request SYN overhead.

**Why it matters:** An HTTP server turns TempleOS into a networked OS that can serve results and receive code without serial bootstrapping.

---

## 3. Bare Metal Support

TempleOS runs on real x86-64 hardware today, but with narrow compatibility.
Terry targeted one specific machine. Modern hardware brings UEFI boot, ACPI,
diverse NIC/GPU/storage controllers, multi-core scheduling improvements.

**The approach:** Start with hardware detection — HolyC probes reporting what's
present (PCI bus scan done ✅, CPUID, ACPI tables). Use that data to prioritize
driver work. One driver at a time.

**Why it matters:** Running on real hardware is the long-term credibility test.
QEMU is a development environment, not the destination.

---

## 4. UI Refresh

TempleOS's interface is functional but visually dated. The DolDoc rendering
system is all HolyC — fonts, colors, layout, widgets are all modifiable without
touching the kernel.

**The approach:** Incremental. Color scheme, cleaner fonts, then richer widgets.
Preserve Terry's design philosophy — keyboard-first, fast, no mouse dependency.

---

## Sequence

| Phase | Goal | Status |
|-------|------|--------|
| Done  | Foundation (serial, crash recovery, exception capture) | ✅ |
| Done  | Code generation pipeline (AgentLoop + Agent class) | ✅ |
| Done  | HTTP client stack (NIC → TCP → HTTP) | ✅ |
| Done  | Test suite (29 suites, 295/296 pass) | ✅ |
| Now   | Kernel bug hunting | 🔄 early findings in bugs.md |
| Near  | HTTP server on TempleOS | ⏳ |
| Mid   | Bare metal hardware detection | ⏳ |
| Mid   | UI refresh | ⏳ |
| Long  | Bare metal driver support | ⏳ |
