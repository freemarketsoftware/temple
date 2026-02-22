#!/usr/bin/env python3
"""
Recursively mirror the TempleOS file tree into brain/real-temple-tree/.
- Uses SerDir to list directories
- Uses SerFileRead to read file contents
- Distinguishes files from dirs by trying SerDir("entry/*")
"""
import socket, time, os, sys

SOCK = '/tmp/temple-serial.sock'
EOT = 0x04
OUT_ROOT = '/home/zero/temple/brain/real-temple-tree'

def recv_until_eot(s, timeout=20):
    buf = b''
    deadline = time.time() + timeout
    s.settimeout(1.0)
    while time.time() < deadline:
        try:
            chunk = s.recv(512)
            if chunk:
                buf += chunk
                if EOT in buf:
                    eot = buf.index(EOT)
                    return buf[:eot]
        except socket.timeout:
            continue
    return None

def send_cmd(s, cmd, timeout=20):
    s.sendall((cmd + '\n').encode())
    return recv_until_eot(s, timeout)

def ser_dir(s, path):
    """Return list of full paths in directory, excluding . and .."""
    raw = send_cmd(s, f'SerDir("{path}/*");')
    if raw is None:
        return []
    lines = raw.decode(errors='replace').strip().splitlines()
    return [l for l in lines if l and not l.endswith('/.') and not l.endswith('/..')]

def ser_file_read(s, path):
    """Return raw bytes of file, or None on failure."""
    raw = send_cmd(s, f'SerFileRead("{path}");', timeout=30)
    return raw

def is_directory(s, path):
    """Try listing path/* — if we get any response (even empty), it's a dir."""
    raw = send_cmd(s, f'SerDir("{path}/*");', timeout=10)
    if raw is None:
        return False
    # If it's a file, SerDir will likely return nothing or garbage
    # If it's a dir, it returns lines (possibly just . and ..)
    lines = raw.decode(errors='replace').strip().splitlines()
    # A directory always has at least . and ..
    has_dot = any(l.endswith('/.') or l == path + '/.' or l == '.' for l in lines)
    has_dotdot = any(l.endswith('/..') or l == path + '/..' or l == '..' for l in lines)
    return has_dot or has_dotdot

def temple_path_to_local(temple_path):
    """Convert C:/Foo/Bar to OUT_ROOT/Foo/Bar"""
    # Strip C:/ prefix
    rel = temple_path.replace('C:/', '').replace('C:\\', '')
    return os.path.join(OUT_ROOT, rel)

def mirror(s, path, depth=0):
    indent = '  ' * depth
    print(f"{indent}DIR  {path}")

    entries = ser_dir(s, path)
    if not entries:
        print(f"{indent}  (empty)")
        return

    for entry in entries:
        name = entry.split('/')[-1]
        local_path = temple_path_to_local(entry)

        if is_directory(s, entry):
            os.makedirs(local_path, exist_ok=True)
            mirror(s, entry, depth + 1)
        else:
            print(f"{indent}  FILE {entry}")
            content = ser_file_read(s, entry)
            if content is not None:
                os.makedirs(os.path.dirname(local_path), exist_ok=True)
                with open(local_path, 'wb') as f:
                    f.write(content)
                print(f"{indent}       -> {len(content)} bytes written")
            else:
                print(f"{indent}       -> FAILED (timeout)")

def main():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK)

    print("Loading SerDir and SerFileRead...")
    send_cmd(s, '#include "C:/Home/SerDir.HC";')
    send_cmd(s, '#include "C:/Home/SerFileRead.HC";')
    print("Ready. Starting mirror...\n")

    mirror(s, 'C:', depth=0)

    s.close()
    print("\nDone.")

if __name__ == '__main__':
    main()
