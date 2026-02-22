#!/usr/bin/env python3
"""
deploy_and_mirror.py

1. Freeze TempleOS
2. Mirror C:/Linux and C:/Misc directories
3. Deploy SerFileExists.HC and SerMkDir.HC to TempleOS
4. Test the new primitives
5. Unfreeze + save snapshot
"""

import sys
import os
import time
import socket

sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

TREE_BASE = '/home/zero/temple/brain/real-temple-tree'
REPO_BASE = '/home/zero/temple/brain/templerepo'

BANNED = {
    'C:/Adam/AutoComplete/ACDefs.DATA',
    'C:/Adam/AutoComplete/ACWords.DATA.Z',
}

BAN_FILE = '/home/zero/temple/brain/file-ban.md'


def safe_filename(tos_path):
    """Convert TempleOS path to local filename."""
    return tos_path.split('/')[-1]


def mirror_dir(t, pattern, local_dir):
    """Mirror a TempleOS directory to local_dir."""
    os.makedirs(local_dir, exist_ok=True)
    print(f"  Listing {pattern} ...")
    entries = t.list_dir(pattern)
    print(f"  Found {len(entries)} entries")

    files = []
    subdirs = []
    for e in entries:
        name = e.split('/')[-1]
        if '.' in name or name == name.upper():
            # Likely a file (has extension or all-caps)
            files.append(e)
        else:
            subdirs.append(e)

    # Actually just try to read everything and distinguish by result
    for entry in entries:
        name = safe_filename(entry)
        local_path = os.path.join(local_dir, name)

        if entry in BANNED:
            print(f"  BANNED  {entry}")
            continue

        # Try listing as directory first
        sub_entries = t.list_dir(entry + '/*')
        if sub_entries is not None and len(sub_entries) > 0:
            # It's a directory
            print(f"  DIR     {entry}/ ({len(sub_entries)} entries)")
            mirror_dir(t, entry + '/*', local_path)
            continue

        # Check if it's an empty dir by seeing if list returns empty
        # Try reading as file
        print(f"  READ    {entry}", end='', flush=True)
        content = t.read_file(entry, timeout=30)
        if content is None:
            print(f" TIMEOUT - banning")
            ban_file(entry, "Timeout during read")
            continue

        # Check for binary content
        try:
            text = content.decode('utf-8', errors='strict')
            # Check for excessive nulls
            if content.count(b'\x00') > len(content) * 0.1:
                text = '(#binary)'
        except Exception:
            text = '(#binary)'

        with open(local_path, 'w', errors='replace') as f:
            if isinstance(text, bytes):
                f.write(text.decode(errors='replace'))
            else:
                f.write(text)

        print(f" {len(content)}b ok")

    return len(entries)


def ban_file(path, reason):
    """Add a file to the ban list."""
    with open(BAN_FILE, 'a') as f:
        f.write(f'| `{path}` | {reason} |\n')
    print(f"  -> Banned: {path}")


def main():
    print("=== TempleOS Deploy + Mirror Script ===\n")

    with Temple() as t:
        # Step 1: Freeze
        print("[1] Freezing TempleOS...")
        t.freeze()
        print("    Frozen. REPL active.\n")

        # Step 2: Mirror Linux and Misc
        for dirname in ['Linux', 'Misc', 'Tmp']:
            pattern = f'C:/{dirname}/*'
            local_dir = os.path.join(TREE_BASE, dirname)
            print(f"[2] Mirroring C:/{dirname}...")
            try:
                n = mirror_dir(t, pattern, local_dir)
                print(f"    Done: {n} entries\n")
            except Exception as e:
                print(f"    ERROR: {e}\n")

        # Step 3: Deploy SerFileExists.HC
        print("[3] Deploying SerFileExists.HC...")
        with open(os.path.join(REPO_BASE, 'SerFileExists.HC'), 'rb') as f:
            exists_code = f.read()
        t.write_file('C:/Home/SerFileExists.HC', exists_code)
        print(f"    Written {len(exists_code)}b\n")

        # Step 4: Deploy SerMkDir.HC
        print("[4] Deploying SerMkDir.HC...")
        with open(os.path.join(REPO_BASE, 'SerMkDir.HC'), 'rb') as f:
            mkdir_code = f.read()
        t.write_file('C:/Home/SerMkDir.HC', mkdir_code)
        print(f"    Written {len(mkdir_code)}b\n")

        # Step 5: Load the new primitives into the REPL
        print("[5] Loading SerFileExists and SerMkDir into REPL...")
        t.exec('#include "C:/Home/SerFileExists.HC";')
        t.exec('#include "C:/Home/SerMkDir.HC";')
        print("    Loaded.\n")

        # Step 6: Test SerFileExists
        print("[6] Testing SerFileExists...")
        exists_yes = t.file_exists('C:/Home/SerReplExe.HC')
        exists_no  = t.file_exists('C:/Home/DOESNOTEXIST.HC')
        print(f"    C:/Home/SerReplExe.HC exists: {exists_yes}  (expect True)")
        print(f"    C:/Home/DOESNOTEXIST.HC exists: {exists_no}  (expect False)")
        ok_exists = exists_yes == True and exists_no == False
        print(f"    Result: {'PASS' if ok_exists else 'FAIL'}\n")

        # Step 7: Test SerMkDir
        print("[7] Testing SerMkDir...")
        t.mkdir('C:/Home/TestMkDir')
        created = t.file_exists('C:/Home/TestMkDir')
        print(f"    C:/Home/TestMkDir exists after mkdir: {created}  (expect True)")
        print(f"    Result: {'PASS' if created else 'FAIL'}\n")

        # Step 8: Unfreeze
        print("[8] Unfreezing...")
        t.unfreeze()
        time.sleep(1)
        print("    Unfrozen.\n")

    # Step 9: Save snapshot
    print("[9] Saving snap1...")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect('/tmp/qmon.sock')
        s.sendall(b'savevm snap1\n')
        time.sleep(2)
    print("    snap1 saved.\n")

    print("=== Done ===")
    print(f"  SerFileExists: {'PASS' if ok_exists else 'FAIL'}")
    print(f"  SerMkDir:      {'PASS' if created else 'FAIL'}")


if __name__ == '__main__':
    main()
