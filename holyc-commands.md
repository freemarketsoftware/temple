# TempleOS HolyC Commands Discovered

## Key Findings

### Sending Keys via QEMU `sendkey`
- Uppercase letters: `shift-a`, `shift-b`, etc.
- `;` (semicolon) → `semicolon`
- `:` (colon) → `shift-semicolon`
- `"` (double quote) → `shift-apostrophe`
- `'` (apostrophe) → `apostrophe`
- `/` (slash) → `slash`
- `(` → `shift-9`
- `)` → `shift-0`
- `#` → `shift-3`
- `\` (backslash) → `backslash`
- Space → `spc`
- Enter → `ret`
- Escape → `esc`

> Use `sendtext.sh` helper script in this folder to type strings reliably.
>
> **Bug fixed:** In bash `case` patterns, `'\\'` matches TWO backslashes, not one.
> Use unquoted `\\)` to match a single backslash character.

---

## Boot Sequence

### Live CD (no install)
TempleOS V5.03 booting from CD asks two questions:

| Prompt | Answer |
|---|---|
| `Install onto hard drive (y or n)?` | `n` — run live from CD |
| `Take Tour (y or n)?` | `n` — skip tour |

After answering both, you land at `T:/Home>` shell prompt. **C: drive does not exist.**

### Installed (from disk)
After installation, boot loader shows:
```
0. Old Boot Record
1. Drive C
2. Drive D
Selection:
```
Select `1` to boot installed TempleOS. Boot sequence auto-runs `#include "Once"` and `MakeHome`. Only one prompt:

| Prompt | Answer |
|---|---|
| `Take Tour (y or n)?` | `n` — skip tour |

Shell prompt is `C:/Home>`.

### Full Install Process
1. Boot from CD, answer `y` to install
2. Answer `y` to "Installing inside QEMU/VMware/VirtualBox?"
3. Files copy automatically to `C:` (takes ~30 seconds)
4. Answer `y` to "Reboot Now?"
5. At boot loader, press `1` for Drive C

---

## Working Commands

### `Print("...\n");`
Output text to the terminal.
```c
Print("Hello World\n");
// Confirmed working — outputs: Hello World
// ans=0x000000A0=160
```

### `Dir;`
Lists the current directory contents (like `ls`).
```c
Dir;
// Returns DATE TIME SIZE columns for each entry
// ans=0x00000002=2 on success
```
- Works correctly on installed C: drive
- On CD boot: fails with "No global labels" (semicolon key was wrong — see gotchas)

### `#include "C:/path/file.HC"`
Execute a HolyC script file.
```c
#include "C:/Home/HelloWorld.HC"
```
- This is how you run .HC script files
- TempleOS uses this for all script execution

### `FileWrite` / `FileRead`
```c
FileWrite("C:/Home/test.DD", "hello", 5);
// Returns non-zero on success (e.g. ans=0x0000551B=21787)

FileRead("C:/Home/test.DD");
// Returns pointer to data buffer (e.g. ans=0x16F415B8)
```
- **Only works on installed C: drive** — T: (CD) is read-only

### `DirMk("C:/path/NewDir");`
Create a new directory.
```c
DirMk("C:/Home/TestDir");
// Output: MakeDirectory:C:/Home/TestDir
// ans=0x00000001=1 on success
```
- Directories appear in `Dir;` output with a `+` prefix (e.g. `+TestDir`)
- **Wrong names:** `MkDir` and `MakeDir` both give `Undefined identifier` — use `DirMk`

### `Del("C:/path/file");`
Delete a file (like `rm`).
```c
Del("C:/Home/DeleteMe.DD");
// Output: Del:DeleteMe.DD
// ans=0x00000001=1 on success
```
- File is immediately gone from `Dir;` listing after deletion

### `Copy("C:/src", "C:/dst");`
Copy a file to a new location.
```c
Copy("C:/Home/test.DD", "C:/Home/test_copy.DD");
// Output: Copying:C:/Home/test.DD to
//         C:/Home/test_copy.DD
// ans=0x00000001=1 on success
```
- Both source and destination must use full absolute paths

### `Find(dir, needle)` — behavior unclear
```c
Find("C:/Home");           // ans=0 — no visible output
Find("C:/Home", "Hello");  // ans=0 — no visible output
Find("C:/", "*.HC");       // ans=0 — no visible output
```
- Consistently returns 0 with no visible output regardless of arguments
- May search compiled binary `.HC.Z` files rather than plain text `.HC` files
- **Not useful for plain text file search**

---

## Writing .HC Script Files

### Recommended: Use `Ed` (the built-in text editor)
`Ed` is the cleanest way to create .HC files. It's a plain text editor — no HolyC
parsing happens on your input, so `"` characters just work with no escaping needed.

```c
Ed("C:/Home/HelloWorld.HC");
```

1. **Must use semicolon** — `Ed("file");` opens blocking in the main left panel. Without semicolon, Ed opens non-blocking in a side panel and `sendkey` input goes to the wrong window.
2. Editor opens with an empty file (title bar shows filename, status bar shows `Line:0001 Col:0001`)
3. Type your script normally — quotes, backslashes, anything works as-is:
   ```
   Print("Hello World\n");
   ```
4. Press `ESC` to save and exit (`ALT-ESC` to abort without saving)
5. Run with `#include "C:/Home/HelloWorld.HC"`

**Confirmed working** — `TestEd.HC` created this way executed correctly.
File saved as plain `.HC` (not compressed), 19 bytes.

> Note: Output from `#include` may not appear until the next command runs — this
> is normal TempleOS buffered rendering behavior. See `weird-temple-behaviors.md`.

---

### Alternative: Byte-by-byte construction (no editor)
If you need to create a file programmatically from the REPL, build the content
in memory using ASCII values to avoid embedded quote issues:
```c
// Writes: Print("Hello World\n");
// ASCII: 34 = ", 92 = \
U8 *b=MAlloc(30);
MemCpy(b,"Print(",6);
b[6]=34;                   // "
MemCpy(b+7,"Hello World",11);
b[18]=92;                  // \
b[19]='n';
b[20]=34;                  // "
b[21]=')';
b[22]=';';
FileWrite("C:/Home/HelloWorld.HC",b,23);
Free(b);
```
- Returns `ans=0x00000030=48` on success
- Run with: `#include "C:/Home/HelloWorld.HC"`

### What Does NOT Work
| Approach | Result |
|---|---|
| `FileWrite(...,"Print(\"Hello World\\n\");",23)` | Parse error — `\"` breaks REPL string parsing |
| `FOpen`/`FPrint` with `%c` | `Undefined identifier at 'c'` error |
| Writing to T: or /Tmp from CD | `ERROR: Not Writable` |

---

## File System Notes

### Drives
| Drive | Writable? | Notes |
|---|---|---|
| `T:` | No | CD filesystem, read-only |
| `/Tmp` | No | Not writable from CD boot |
| `C:` | **Yes** | Writable after installing to `TempleOS.qcow2` |

---

## Gotchas & Lessons Learned

### Wrong semicolon key caused all early failures
- `shift-semicolon` sends `:` (colon), NOT `;`
- `;` is just `semicolon` (no shift)
- All early `Dir;` attempts were actually sending `Dir:` — invalid HolyC

### `#include "Once"` causes reboot if already loaded
- Running it on an already-initialized system triggers full OS re-init
- Only run if you get "No global labels" on a fresh shell

### `Dir;` after wrong sendkey → misleading error
- `ERROR: No global labels at "Dir"` actually meant syntax error (`Dir:` not `Dir;`)

### `colon` is not a valid QEMU sendkey name
- Use `shift-semicolon` for `:`

### Wrong mkdir name: `MkDir`/`MakeDir` do not exist
- Both give `ERROR: Undefined identifier at "("`
- The correct function is `DirMk("C:/path/dir")`

---

## HolyC Quick Reference

```c
Print("text\n");              // print to terminal
DocClear(DocPut);             // clear the terminal screen
Dir;                          // list current directory
Cd("C:/path");                // change directory
Ed("C:/Home/file.HC");        // open text editor (ESC to save, ALT-ESC to abort)
FileWrite("C:/f.DD","hi",2); // write file (C: only)
FileRead("C:/f.DD");          // read file
DirMk("C:/Home/NewDir");     // create a directory (+ prefix in Dir output)
Del("C:/Home/file.DD");       // delete a file
Copy("C:/src","C:/dst");      // copy a file
MAlloc(size);                 // allocate memory
MemCpy(dst,src,n);            // copy memory
Free(ptr);                    // free memory
Reboot;                       // reboot TempleOS
Exit;                         // exit current task
#include "C:/Home/script.HC"  // run a script file
```

---

## QEMU Monitor Commands (from Linux host)

```bash
# All commands piped via:
echo "COMMAND" | sudo nc -q 1 -U /tmp/qmon.sock

echo "system_reset"          # reboot VM
echo "savevm snap1"          # save snapshot
echo "loadvm snap1"          # restore snapshot
echo "info snapshots"        # list snapshots
echo "screendump /tmp/s.ppm" # screenshot (PPM format)
echo "sendkey n"             # send keystroke
echo "quit"                  # shut down QEMU
```

---

## Screenshot Pipeline

```bash
echo "screendump /tmp/screen.ppm" | sudo nc -q 1 -U /tmp/qmon.sock
sudo python3 -c "from PIL import Image; Image.open('/tmp/screen.ppm').save('/tmp/screen.png')"
sudo chown zero:zero /tmp/screen.png
```
