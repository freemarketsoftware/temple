#!/usr/bin/env python3
"""
deploy_all.py — Deploy all HC files from brain/templerepo/ to C:/Home/ on TempleOS.

Run this after any loadvm to restore files lost by snapshot disk reversion.
Also creates C:/AI/ workspace directories if they don't exist.

Usage:
    sudo python3 serial/deploy_all.py
"""
import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

REPO_DIR = os.path.join(os.path.dirname(__file__), '..', 'brain', 'templerepo')

# Files to deploy (in dependency order — SerProto must be first)
FILES = [
    'SerProto.HC',
    'SerDir.HC',
    'SerFileRead.HC',
    'SerFileWrite.HC',
    'SerFileExists.HC',
    'SerMkDir.HC',
    'SerExecI64.HC',
    'SerExecStr.HC',
    'SerSymExists.HC',
    'SerSymList.HC',
    'SerMemInfo.HC',
    'SerReplExe.HC',
]

AI_DIRS = [
    'C:/AI',
    'C:/AI/code',
    'C:/AI/tests',
    'C:/AI/results',
]

def wait_freeze(t, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if t.is_frozen(timeout=2):
            return True
        time.sleep(0.5)
    return False


def main():
    with Temple() as t:
        # Ensure REPL is running
        if not t.is_frozen(timeout=3):
            print('REPL not running — starting SerReplExe...')
            t._sendkey('#include "C:/Home/SerReplExe.HC"')
            time.sleep(1)
            t._sendkey('Dir;')
            if not wait_freeze(t, timeout=20):
                print('ERROR: Could not start REPL. Is TempleOS at the command prompt?')
                sys.exit(1)
            print('REPL ready.')
        else:
            print('REPL already running.')

        # Deploy HC files
        print(f'\nDeploying {len(FILES)} HC files to C:/Home/...')
        ok = 0
        for fname in FILES:
            src = os.path.join(REPO_DIR, fname)
            dst = f'C:/Home/{fname}'
            if not os.path.exists(src):
                print(f'  [SKIP] {fname} — not in templerepo')
                continue
            with open(src, 'rb') as f:
                content = f.read()
            try:
                t.write_file(dst, content)
                print(f'  [OK]   {fname}  ({len(content)}b)')
                ok += 1
            except Exception as e:
                print(f'  [FAIL] {fname}: {e}')

        # Create AI workspace dirs
        print(f'\nEnsuring AI workspace directories...')
        for d in AI_DIRS:
            try:
                if not t.file_exists(d + '/.'):
                    t.mkdir(d)
                    print(f'  [CREATED] {d}')
                else:
                    print(f'  [EXISTS]  {d}')
            except Exception as e:
                print(f'  [SKIP]    {d}: {e}')

        print(f'\nDone. {ok}/{len(FILES)} files deployed.')
        t.unfreeze()


if __name__ == '__main__':
    main()
