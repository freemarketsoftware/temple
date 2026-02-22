#!/usr/bin/env python3
"""
mirror_fix.py

Fix Linux directory mirroring (GodPassage is a subdirectory).
Also validate SerMkDir works by checking via list_dir instead of file_exists.
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


def mirror_entry(t, tos_path, local_path):
    """Mirror a single TempleOS path (file or dir) to local_path."""
    if tos_path in BANNED:
        print(f"  BANNED  {tos_path}")
        return

    # Use file_exists to distinguish file from directory
    is_file = t.file_exists(tos_path)

    if is_file:
        print(f"  FILE    {tos_path}", end='', flush=True)
        content = t.read_file(tos_path, timeout=30)
        if content is None:
            print(" TIMEOUT")
            ban_file(tos_path, "Timeout during read")
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

        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        with open(local_path, 'w', errors='replace') as f:
            f.write(text)
        print(f" {len(content)}b ok")

    else:
        # It's a directory (or empty — both show as not-file)
        pattern = tos_path + '/*'
        entries = t.list_dir(pattern)
        if entries is None:
            entries = []
        print(f"  DIR     {tos_path}/ ({len(entries)} entries)")
        os.makedirs(local_path, exist_ok=True)
        for entry in entries:
            name = entry.split('/')[-1]
            mirror_entry(t, entry, os.path.join(local_path, name))


def main():
    print("=== Mirror Fix + SerMkDir Test ===\n")

    with Temple() as t:
        print("[1] Freezing...")
        t.freeze()
        # Load new primitives
        t.exec('#include "C:/Home/SerFileExists.HC";')
        t.exec('#include "C:/Home/SerMkDir.HC";')
        print("    Frozen + primitives loaded.\n")

        # Mirror Linux
        print("[2] Mirroring C:/Linux...")
        linux_dir = os.path.join(TREE_BASE, 'Linux')
        entries = t.list_dir('C:/Linux/*')
        print(f"    Found {len(entries)} entries")
        for entry in entries:
            name = entry.split('/')[-1]
            mirror_entry(t, entry, os.path.join(linux_dir, name))
        print()

        # Test SerMkDir properly using list_dir
        print("[3] Testing SerMkDir...")
        test_dir = 'C:/Home/TestMkDir2'
        t.mkdir(test_dir)
        time.sleep(0.5)
        # Check if it appears in parent dir listing
        home_entries = t.list_dir('C:/Home/*')
        found = any(e == test_dir or e.endswith('/TestMkDir2') for e in home_entries)
        print(f"    {test_dir} in C:/Home listing: {found}  (expect True)")
        print(f"    Result: {'PASS' if found else 'FAIL'}\n")

        # Unfreeze
        print("[4] Unfreezing...")
        t.unfreeze()
        time.sleep(1)
        print("    Unfrozen.\n")

    # Save snapshot
    print("[5] Saving snap1...")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect('/tmp/qmon.sock')
        s.sendall(b'savevm snap1\n')
        time.sleep(2)
    print("    snap1 saved.\n")

    print("=== Done ===")


if __name__ == '__main__':
    main()
