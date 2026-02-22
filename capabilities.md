# TempleOS / QEMU Programmatic Capabilities

## Environment
- TempleOS V5.03 running on QEMU 6.2.0 (x86_64)
- Disk image: `TempleOS.qcow2`
- QEMU monitor exposed via Unix socket: `/tmp/qmon.sock`
- Display: GTK window (`-display gtk`)

---

## Capabilities

### 1. VM Lifecycle Control (via QEMU monitor)
```bash
echo "quit"         | nc -U /tmp/qmon.sock   # shut down QEMU
echo "system_reset" | nc -U /tmp/qmon.sock   # reboot TempleOS
echo "stop"         | nc -U /tmp/qmon.sock   # pause execution
echo "cont"         | nc -U /tmp/qmon.sock   # resume execution
```

### 2. Snapshots
```bash
echo "savevm snap1"   | nc -U /tmp/qmon.sock  # save VM state
echo "loadvm snap1"   | nc -U /tmp/qmon.sock  # restore VM state
echo "delvm snap1"    | nc -U /tmp/qmon.sock  # delete snapshot
```

### 3. Screenshot (blind read-back)
```bash
echo "screendump /tmp/screen.ppm" | nc -U /tmp/qmon.sock
# Result is a PPM image of the current TempleOS display
# Can be processed with ImageMagick or similar for OCR
```

### 4. Keystroke Injection (`sendkey`)
The only way to "type" into TempleOS programmatically.
```bash
# Send individual keys
echo "sendkey h"      | nc -U /tmp/qmon.sock
echo "sendkey ret"    | nc -U /tmp/qmon.sock  # Enter

# Example: type a HolyC expression and execute it
for key in D i r S e m i c o l o n ret; do
  echo "sendkey $key" | nc -U /tmp/qmon.sock
  sleep 0.05
done
```
Special key names: `ret`, `spc`, `backspace`, `esc`, `tab`, `ctrl-c`, `shift-*`

### 5. Disk Image Inspection (VM stopped)
```bash
qemu-img info temple/TempleOS.qcow2   # image metadata
qemu-img snapshot -l temple/TempleOS.qcow2  # list snapshots
```

### 6. ISO / Media Swap
```bash
echo "change ide1-cd0 /path/to/new.iso" | nc -U /tmp/qmon.sock
```

---

## Interaction Loop Pattern
The closest thing to a programmatic REPL:
1. Send keystrokes via `sendkey` to type a HolyC command
2. Send `ret` to execute
3. Capture `screendump` to see output
4. Optionally use OCR (e.g. `tesseract`) to parse the result

---

## Hard Limitations
| Limitation | Reason |
|---|---|
| No network access | TempleOS has no network stack by design |
| No filesystem mount | TempleOS uses RedSea FS — unsupported by Linux |
| No stdout capture | Output only visible via screendump |
| No file injection | No network, no mountable FS |
| Blind typing | No confirmation a keystroke was received correctly |

---

## HolyC Quick Reference (for sendkey scripting)
```c
Dir;               // list files
FileWrite("f.DD","hello",5);  // write a file
FileRead("f.DD");             // read a file
Reboot;            // reboot TempleOS
Exit;              // exit current task
```

---

## Starting QEMU
```bash
qemu-system-x86_64 \
  -m 512 \
  -hda temple/TempleOS.qcow2 \
  -cdrom temple/TempleOSCDV5.03.ISO \
  -boot c \
  -vga std \
  -display gtk \
  -monitor unix:/tmp/qmon.sock,server,nowait
```
