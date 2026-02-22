#!/usr/bin/env python3
"""
run_test.py — Deploy and run a TempleOS-side HolyC test.

Usage:
    sudo python3 serial/run_test.py brain/templerepo/TestMalloc.HC
"""
import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

def wait_freeze(t, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if t.is_frozen(timeout=2): return True
        time.sleep(0.5)
    return False

def main():
    if len(sys.argv) < 2:
        print("Usage: sudo python3 serial/run_test.py <path/to/TestXxx.HC>")
        sys.exit(1)

    src = sys.argv[1]
    fname = os.path.basename(src)
    dest = f'C:/AI/tests/{fname}'
    results_path = f'C:/AI/results/{fname.replace(".HC", ".txt")}'

    with open(src, 'rb') as f:
        content = f.read()

    with Temple() as t:
        # Ensure REPL is running
        if not t.is_frozen(timeout=3):
            print('Starting REPL...')
            t._sendkey('#include "C:/Home/SerReplExe.HC"')
            time.sleep(1)
            t._sendkey('Dir;')
            if not wait_freeze(t, timeout=20):
                print('ERROR: REPL did not start')
                sys.exit(1)

        # Deploy test file
        print(f'Deploying {fname} -> {dest}')
        t.write_file(dest, content)

        # Run it
        print(f'Running...')
        t.send_cmd(f'#include "{dest}";')

        # Read results
        print(f'Reading results from {results_path}')
        raw = t.read_file(results_path, timeout=10)
        if not raw:
            print('No results file found.')
            t.unfreeze()
            return

        lines = raw.decode(errors='replace').splitlines()
        print()
        passed = failed = 0
        for line in lines[1:]:  # skip header
            if not line.strip():
                continue
            parts = line.split('\t')
            name = parts[0] if len(parts) > 0 else '?'
            status = parts[1] if len(parts) > 1 else '?'
            detail = parts[2] if len(parts) > 2 else ''
            marker = '[PASS]' if status == 'PASS' else '[FAIL]'
            print(f'  {marker} {name}: {detail}')
            if status == 'PASS': passed += 1
            else: failed += 1

        print(f'\nResult: {passed} passed, {failed} failed')
        t.unfreeze()

if __name__ == '__main__':
    main()
