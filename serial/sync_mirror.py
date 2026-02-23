#!/usr/bin/env python3
"""
sync_mirror.py — Mirror C:/Home/ and C:/AI/ from TempleOS to local brain/real-temple-tree/

Usage:
    sudo python3 serial/sync_mirror.py
"""
import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

TREE_BASE = os.path.join(os.path.dirname(__file__), '..', 'brain', 'real-temple-tree')

BANNED = {
    'C:/Adam/AutoComplete/ACDefs.DATA',
    'C:/Adam/AutoComplete/ACWords.DATA.Z',
    'C:/Kernel/Kernel.PRJ.Z',
    'C:/Misc/Bible.TXT.Z',
}

stats = {'files': 0, 'dirs': 0, 'skipped': 0, 'errors': 0}


def temple_to_local(temple_path):
    rel = temple_path.replace('C:/', '').replace('C:\\', '')
    return os.path.join(TREE_BASE, rel)


def is_dir(t, path):
    """Check if path is a directory by attempting to list it."""
    entries = t.list_dir(path + '/*')
    return entries is not None and len(entries) >= 0


def mirror_dir(t, temple_path, depth=0):
    indent = '  ' * depth
    entries = t.list_dir(temple_path + '/*')
    if entries is None:
        print(f'{indent}  (list failed)')
        return

    local_dir = temple_to_local(temple_path)
    os.makedirs(local_dir, exist_ok=True)
    stats['dirs'] += 1

    for entry in entries:
        if entry in BANNED:
            print(f'{indent}  [BANNED]  {entry}')
            stats['skipped'] += 1
            continue

        name = entry.split('/')[-1]
        local_path = temple_to_local(entry)

        # Directories have no extension; files always do in TempleOS
        if '.' not in name:
            print(f'{indent}  [DIR]  {name}/')
            mirror_dir(t, entry, depth + 1)
            continue

        # It's a file — read it
        print(f'{indent}  [FILE] {name}', end='', flush=True)
        content = t.read_file(entry, timeout=30)
        if content is None:
            print(f'  TIMEOUT')
            stats['errors'] += 1
            continue

        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        with open(local_path, 'wb') as f:
            f.write(content)
        print(f'  ({len(content)}b)')
        stats['files'] += 1


def wait_freeze(t, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if t.is_frozen(timeout=2):
            return True
        time.sleep(0.5)
    return False


def main():
    targets = [
        ('C:/Home',  'Home'),
        ('C:/AI',    'AI'),
    ]

    with Temple() as t:
        if not t.is_frozen(timeout=3):
            print('Starting REPL...')
            t._sendkey('#include "C:/Home/SerReplExe.HC"')
            time.sleep(1)
            t._sendkey('Dir;')
            if not wait_freeze(t, timeout=20):
                print('ERROR: REPL did not start')
                sys.exit(1)

        # Load primitives needed for mirroring
        t.send_cmd('#include "C:/Home/SerDir.HC";')
        t.send_cmd('#include "C:/Home/SerFileRead.HC";')
        print('REPL ready.\n')

        for temple_path, label in targets:
            print(f'=== Mirroring {temple_path} ===')
            mirror_dir(t, temple_path, depth=0)
            print()

        t.unfreeze()

    print(f'Done: {stats["files"]} files, {stats["dirs"]} dirs, '
          f'{stats["skipped"]} skipped, {stats["errors"]} errors')


if __name__ == '__main__':
    main()
