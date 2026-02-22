#!/usr/bin/env python3
"""Deploy SerExecI64.HC and test exec_i64."""

import sys, os, time, socket
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

REPO = '/home/zero/temple/brain/templerepo'

def main():
    print("=== Deploy + Test SerExecI64 ===\n")

    with Temple() as t:
        print("[1] Freezing...")
        t.freeze()
        print("    Ready.\n")

        print("[2] Deploying SerExecI64.HC...")
        with open(f'{REPO}/SerExecI64.HC', 'rb') as f:
            code = f.read()
        t.write_file('C:/Home/SerExecI64.HC', code)
        print(f"    Written {len(code)}b")

        print("[3] Loading into REPL...")
        t.exec('#include "C:/Home/SerExecI64.HC";')
        print("    Loaded.\n")

        print("[4] Testing exec_i64...")
        tests = [
            ('2+2', 4),
            ('1024*1024', 1048576),
            ('100-1', 99),
            ('0', 0),
            ('-42', -42),
        ]
        all_pass = True
        for expr, expected in tests:
            result = t.exec_i64(expr)
            ok = result == expected
            all_pass = all_pass and ok
            status = 'PASS' if ok else f'FAIL (got {result})'
            print(f"    {expr} = {result}  (expect {expected})  {status}")

        print(f"\n    Overall: {'ALL PASS' if all_pass else 'SOME FAILED'}\n")

        print("[5] Unfreezing...")
        t.unfreeze()
        time.sleep(1)

    print("[6] Saving snap1...")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect('/tmp/qmon.sock')
        s.sendall(b'savevm snap1\n')
        time.sleep(2)
    print("    Saved.\n")

    print("=== Done ===")

if __name__ == '__main__':
    main()
