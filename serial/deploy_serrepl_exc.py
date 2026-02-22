#!/usr/bin/env python3
"""
Deploy new SerReplExe.HC (with exception capture) and test.
Uses is_frozen() polling to wait for REPL before sending serial commands.
"""
import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple, TempleException

REPO = '/home/zero/temple/brain/templerepo'

def wait_freeze(t, timeout=20):
    """Poll is_frozen() until REPL is up or timeout."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        if t.is_frozen(timeout=2):
            return True
        time.sleep(0.5)
    return False

def main():
    print("=== Deploy SerReplExe (exception capture) ===\n")

    with Temple() as t:
        # 1. If not frozen, freeze
        if not t.is_frozen(timeout=2):
            print("[1] Freezing...")
            t._sendkey('#include "C:/Home/SerReplExe.HC"')
            time.sleep(1)
            t._sendkey('Dir;')
            if not wait_freeze(t, timeout=15):
                print("    FAIL: could not freeze. Try loading snap1 first.")
                return
            print("    Frozen.")
        else:
            print("[1] Already frozen.")

        # 2. Load only the primitives we need
        print("[2] Loading file primitives...")
        for prim in ['SerDir', 'SerFileRead', 'SerFileWrite',
                     'SerFileExists', 'SerMkDir', 'SerExecI64', 'SerExecStr']:
            t.send_cmd(f'#include "C:/Home/{prim}.HC";')
        print("    Done.")

        # 3. Deploy new SerReplExe.HC
        print("[3] Deploying new SerReplExe.HC...")
        with open(f'{REPO}/SerReplExe.HC', 'rb') as f:
            code = f.read()
        t.write_file('C:/Home/SerReplExe.HC', code)
        print(f"    Deployed ({len(code)}b)")

        # 4. Reload with new SerReplExe
        print("[4] Reloading with new SerReplExe...")
        t.unfreeze()
        time.sleep(1)
        t._sendkey('#include "C:/Home/SerReplExe.HC"')
        time.sleep(1)
        t._sendkey('Dir;')
        if not wait_freeze(t, timeout=15):
            print("    FAIL: new SerReplExe did not start.")
            return
        print("    Frozen with new SerReplExe.")

        # Reload primitives
        for prim in ['SerDir', 'SerFileRead', 'SerFileWrite',
                     'SerFileExists', 'SerMkDir', 'SerExecI64', 'SerExecStr']:
            t.send_cmd(f'#include "C:/Home/{prim}.HC";')

        # 5. Tests
        print("\n[5] Normal exec still works...")
        r = t.exec_str('GStrAdd("ok");')
        assert r == 'ok', f"FAIL: {r!r}"
        print(f"    PASS: {r!r}")

        print("[6] Runtime exception (explicit throw)...")
        try:
            t.exec_str('throw(12345);')
            print("    FAIL: no exception raised")
        except TempleException as e:
            print(f"    PASS: TempleException({e!r})")

        print("[7] Runtime exception (div by zero)...")
        try:
            t.exec_str('I64 x=0;I64 y=1/x;GStrAdd("ok");')
            print("    FAIL: no exception raised")
        except TempleException as e:
            print(f"    PASS: TempleException({e!r})")

        print("[8] REPL still alive after exceptions...")
        r = t.exec_str('GStrAdd("survived");')
        assert r == 'survived', f"FAIL: {r!r}"
        print(f"    PASS: {r!r}")

        print("\n[unfreeze]")
        t.unfreeze()

    print("\n=== Done ===")

if __name__ == '__main__':
    main()
