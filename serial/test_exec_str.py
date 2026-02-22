#!/usr/bin/env python3
"""Interactive SerExecStr test suite."""

import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

def run_test(label, result, expected=None):
    if expected is None:
        print(f"  {label}: '{result}'")
    else:
        ok = result == expected
        print(f"  {label}: '{result}'  {'PASS' if ok else f'FAIL (expected: {repr(expected)})'}")
    return result

def main():
    print("=== SerExecStr Test Suite ===\n")

    with Temple() as t:
        print("[freeze]")
        t.freeze()
        print(f"  frozen: {t.is_frozen()}\n")

        # 1. Basic GStrAdd
        print("[1] Basic GStrAdd")
        run_test("hello", t.exec_str('GStrAdd("hello world");'), "hello world")

        # 2. StrPrint formatting
        print("[2] StrPrint formatting")
        run_test("int",    t.exec_str('StrPrint(g_str,"%d",42);'), "42")
        run_test("float",  t.exec_str('StrPrint(g_str,"%.2f",3.14);'), "3.14")
        run_test("hex",    t.exec_str('StrPrint(g_str,"%X",0xDEAD);'), "DEAD")
        run_test("string", t.exec_str('StrPrint(g_str,"%s","TempleOS");'), "TempleOS")

        # 3. Multi-append
        print("[3] GStrAdd append")
        run_test("append", t.exec_str('GStrAdd("foo");GStrAdd("|");GStrAdd("bar");'), "foo|bar")

        # 4. Math results
        print("[4] Math via StrPrint")
        run_test("addition",  t.exec_str('StrPrint(g_str,"%d",100+200);'), "300")
        run_test("multiply",  t.exec_str('StrPrint(g_str,"%d",7*8);'), "56")
        run_test("bitshift",  t.exec_str('StrPrint(g_str,"%d",1<<10);'), "1024")

        # 5. Live kernel data
        print("[5] Live kernel data")
        run_test("cpu cores", t.exec_str('StrPrint(g_str,"%d",mp_cnt);'))
        run_test("time (tS)", t.exec_str('StrPrint(g_str,"%f",tS());'))
        run_test("cur dir",   t.exec_str('GStrAdd(DirCur());'))

        # 6. String functions
        print("[6] String functions")
        run_test("StrLen",  t.exec_str('StrPrint(g_str,"%d",StrLen("hello"));'), "5")
        run_test("StrICmp", t.exec_str('StrPrint(g_str,"%d",StrICmp("ABC","abc"));'), "0")

        # 7. File system queries
        print("[7] File system")
        run_test("file exists?", t.exec_str(
            'if(FileFind("C:/Home/SerReplExe.HC"))GStrAdd("yes");else GStrAdd("no");'), "yes")
        run_test("missing file?", t.exec_str(
            'if(FileFind("C:/Home/NOPE.HC"))GStrAdd("yes");else GStrAdd("no");'), "no")

        # 8. Multi-line logic (packed into one line)
        print("[8] Logic")
        run_test("loop sum", t.exec_str(
            'I64 s=0;I64 i;for(i=1;i<=10;i++)s+=i;StrPrint(g_str,"%d",s);'), "55")

        print("\n[unfreeze]")
        t.unfreeze()

    print("\n=== Done ===")

if __name__ == '__main__':
    main()
