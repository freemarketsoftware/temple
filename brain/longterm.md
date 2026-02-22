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
HolyC test cases, runs them through the pipeline, and documents findings.
This is the first real autonomous task — it works entirely within what we
already have.

**Why it matters:** Any serious work on TempleOS (networking, UI, bare metal)
will touch the kernel. Understanding its failure modes first is essential.

---

## 2. HTTP Stack

TempleOS has no networking by design — Terry considered the internet a
distraction. We disagree for the purpose of this project.

QEMU emulates an e1000 NIC. The path is:

```
e1000 NIC driver → ARP / IP → TCP / UDP → HTTP client + server
```

Each layer is a discrete project. The NIC driver is the hardest — it requires
writing directly to memory-mapped I/O registers and handling interrupts. The
upper layers (IP, TCP, HTTP) are complex but straightforward HolyC once the
driver exists.

**QEMU-first:** Develop and validate entirely in QEMU before considering
real hardware. The e1000 is well-documented and QEMU's emulation is
deterministic.

**Why it matters:** An HTTP stack turns TempleOS into a networked OS.
Claude can serve results, receive code, and interact with external systems.

---

## 3. Bare Metal Support

TempleOS runs on real x86-64 hardware today, but with narrow compatibility.
Terry targeted one specific machine (his own). Modern hardware brings:
UEFI boot, ACPI power management, diverse NIC / GPU / storage controllers,
multi-core scheduling improvements.

**The approach:** Start with hardware detection — write HolyC probes that
report what's present (PCI bus scan, CPUID, ACPI tables). Use that data to
prioritize driver work. One driver at a time.

**Why it matters:** Running on real hardware is the long-term credibility test.
QEMU is a development environment, not the destination.

---

## 4. UI Refresh

TempleOS's interface is functional but visually dated and uninviting to new
users. The DolDoc rendering system is all HolyC — fonts, colors, layout,
widgets are all modifiable without touching the kernel.

**The approach:** Incremental. Start with a color scheme update and cleaner
default fonts. Then richer widgets (proper buttons, panels, scrollbars).
Eventually a compositor that feels intentional rather than accidental.

**The constraint:** Preserve Terry's design philosophy — no mouse dependency,
keyboard-first, fast. A refresh should feel like a cleaned-up version of
TempleOS, not a different OS wearing its skin.

---

## Sequence

These goals depend on each other. The natural order:

| Phase | Goal | Depends on |
|-------|------|------------|
| Now | Code generation pipeline | Foundation (done) |
| Near | AI workspace | Pipeline |
| Near | Kernel bug hunting | Pipeline + workspace |
| Mid | NIC driver / HTTP stack | Kernel understanding |
| Mid | UI refresh | Kernel stability |
| Long | Bare metal support | All of the above |

The pipeline is the unlock. Without reliable write → load → execute → iterate,
none of the above is achievable autonomously.
