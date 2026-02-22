#!/usr/bin/env python3
"""
mirror_linux.py

Mirror C:/Linux, test SerMkDir properly, save snapshot.
Strategy: list_dir first to detect directories, fallback to file read.
"""

import sys
import os
import time
import socket

sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

TREE_BASE = '/home/zero/temple/brain/real-temple-tree'
BAN_FILE  = '/home/zero/temple/brain/file-ban.md'

BANNED = {
    'C:/Adam/AutoComplete/ACDefs.DATA',
    'C:/Adam/AutoComplete/ACWords.DATA.Z',
    'C:/Misc/Bible.TXT.Z',
}


def ban_file(path, reason):
    with open(BAN_FILE, 'a') as f:
        f.write(f'| `{path}` | {reason} |\n')
    print(f"      -> Banned: {path}")


def mirror_entry(t, tos_path, local_path, depth=0):
    """Mirror a single TempleOS path (file or dir) to local_path."""
    indent = '  ' * (depth + 1)

    if tos_path in BANNED:
        print(f"{indent}BANNED  {tos_path}")
        return

    # First: try listing as directory
    sub_entries = t.list_dir(tos_path + '/*')
    if sub_entries:
        # Has sub-entries -> it's a directory
        print(f"{indent}DIR     {tos_path}/ ({len(sub_entries)} entries)")
        os.makedirs(local_path, exist_ok=True)
        for entry in sub_entries:
            name = entry.split('/')[-1]
            mirror_entry(t, entry, os.path.join(local_path, name), depth + 1)
        return

    # No sub-entries: could be empty dir or file
    # Try reading as file
    print(f"{indent}READ    {tos_path}", end='', flush=True)
    content = t.read_file(tos_path, timeout=30)
    if content is None:
        print(" TIMEOUT")
        ban_file(tos_path, "Timeout during read")
        return

    if len(content) == 0:
        print(" empty")
        # Could be empty dir - create as directory
        os.makedirs(local_path, exist_ok=True)
        return

    # Check for binary content
    null_count = content.count(b'\x00')
    if null_count > len(content) * 0.1:
        text = '(#binary)'
    else:
        try:
            text = content.decode('utf-8', errors='strict')
        except Exception:
            text = content.decode('latin-1', errors='replace')

    # If local_path is already a directory, write index file inside it
    if os.path.isdir(local_path):
        local_path = os.path.join(local_path, '_contents.txt')

    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    with open(local_path, 'w', errors='replace') as f:
        if isinstance(text, bytes):
            f.write(text.decode(errors='replace'))
        else:
            f.write(text)
    print(f" {len(content)}b ok")


def main():
    print("=== Mirror Linux + Test SerMkDir ===\n")

    with Temple() as t:
        print("[1] Freezing...")
        t.freeze()
        t.exec('#include "C:/Home/SerFileExists.HC";')
        t.exec('#include "C:/Home/SerMkDir.HC";')
        print("    Ready.\n")

        # Mirror Linux
        print("[2] Mirroring C:/Linux...")
        linux_dir = os.path.join(TREE_BASE, 'Linux')
        os.makedirs(linux_dir, exist_ok=True)
        entries = t.list_dir('C:/Linux/*')
        print(f"    Found {len(entries)} entries: {entries}")
        for entry in entries:
            name = entry.split('/')[-1]
            mirror_entry(t, entry, os.path.join(linux_dir, name))
        print()

        # Test SerMkDir using list_dir
        print("[3] Testing SerMkDir via list_dir...")
        test_dir = 'C:/Home/TestMkDir3'
        t.mkdir(test_dir)
        time.sleep(0.5)
        home_entries = t.list_dir('C:/Home/*')
        found = any(e == test_dir or e.endswith('/TestMkDir3') for e in home_entries)
        print(f"    {test_dir} found in C:/Home/*: {found}")
        print(f"    All C:/Home entries: {[e.split('/')[-1] for e in home_entries]}")
        print(f"    Result: {'PASS' if found else 'FAIL'}\n")

        print("[4] Unfreezing...")
        t.unfreeze()
        time.sleep(1)
        print("    Done.\n")

    print("[5] Saving snap1...")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect('/tmp/qmon.sock')
        s.sendall(b'savevm snap1\n')
        time.sleep(2)
    print("    Saved.\n")

    print("=== Done ===")


if __name__ == '__main__':
    main()
