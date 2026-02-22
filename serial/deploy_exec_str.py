#!/usr/bin/env python3
"""
Deploy SerExecI64 + SerExecStr and test.
Bootstrap: partial freeze (no new primitives), deploy, load, test.
"""
import sys, os, time, socket
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

REPO = '/home/zero/temple/brain/templerepo'

def partial_freeze(t):
    t._sendkey('#include "C:/Home/SerReplExe.HC"')
    time.sleep(1)
    t._sendkey('Dir;')
    time.sleep(2)
    t.send_cmd('#include "C:/Home/SerDir.HC";')
    t.send_cmd('#include "C:/Home/SerFileRead.HC";')
    t.send_cmd('#include "C:/Home/SerFileWrite.HC";')
    t.send_cmd('#include "C:/Home/SerFileExists.HC";')
    t.send_cmd('#include "C:/Home/SerMkDir.HC";')

def main():
    print("=== Deploy SerExecI64 + SerExecStr ===\n")

    with Temple() as t:
        print("[1] Partial freeze...")
        partial_freeze(t)
        print("    Ready.\n")

        for name in ['SerExecI64.HC', 'SerExecStr.HC']:
            with open(f'{REPO}/{name}', 'rb') as f:
                code = f.read()
            t.write_file(f'C:/Home/{name}', code)
            print(f"    Deployed {name} ({len(code)}b)")

        print("\n[2] Loading into REPL...")
        t.send_cmd('#include "C:/Home/SerExecI64.HC";')
        t.send_cmd('#include "C:/Home/SerExecStr.HC";')
        print("    Loaded.\n")

        # Test exec_i64
        print("[3] exec_i64...")
        for expr, expected in [('2+2', 4), ('1024*1024', 1048576), ('-42', -42), ('0', 0)]:
            result = t.exec_i64(expr)
            print(f"    {expr} = {result}  {'PASS' if result == expected else f'FAIL (expected {expected})'}")

        # Test exec_str
        print("\n[4] exec_str with GStrAdd...")
        result = t.exec_str('GStrAdd("hello from TempleOS");')
        print(f"    '{result}'  {'PASS' if result == 'hello from TempleOS' else 'FAIL'}")

        print("[5] exec_str with StrPrint...")
        result = t.exec_str('StrPrint(g_str,"val=%d",42);')
        print(f"    '{result}'  {'PASS' if result == 'val=42' else 'FAIL'}")

        print("[6] exec_str append...")
        result = t.exec_str('GStrAdd("foo");GStrAdd(" bar");')
        print(f"    '{result}'  {'PASS' if result == 'foo bar' else 'FAIL'}")

        print("[7] exec_str StrPrint format...")
        result = t.exec_str('StrPrint(g_str,"%d + %d = %d",3,4,3+4);')
        print(f"    '{result}'  {'PASS' if result == '3 + 4 = 7' else 'FAIL'}")

        print("\n[8] Unfreezing...")
        t.unfreeze()
        time.sleep(1)

    print("[9] Saving snap1...")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect('/tmp/qmon.sock')
        s.sendall(b'savevm snap1\n')
        time.sleep(2)
    print("    Saved.\n=== Done ===")

if __name__ == '__main__':
    main()
