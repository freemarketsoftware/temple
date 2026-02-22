#!/usr/bin/env python3
"""
Kernel basic sanity tests.
Tests MAlloc/Free/MSize, string functions, and integer edge cases.
Results written to C:/AI/results/kernel_basic.txt on TempleOS.
"""
import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple, TempleException

RESULTS_PATH = 'C:/AI/results/kernel_basic.txt'

def wait_freeze(t, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if t.is_frozen(timeout=2): return True
        time.sleep(0.5)
    return False

def run_test(t, name, code, expect=None):
    try:
        result = t.exec_str(code)
        if expect is not None:
            passed = result.strip() == str(expect)
        else:
            passed = True
        status = 'PASS' if passed else 'FAIL'
        detail = f"{result!r}" if expect is None else f"{result!r} (expected {expect!r})"
        print(f"  [{status}] {name}: {detail}")
        return status, result
    except TempleException as e:
        print(f"  [EXCP] {name}: TempleException({str(e)!r})")
        return 'EXCP', str(e)

def main():
    results = []

    with Temple() as t:
        if not t.is_frozen(timeout=2):
            t._sendkey('#include "C:/Home/SerReplExe.HC"')
            time.sleep(1); t._sendkey('Dir;')
            wait_freeze(t, timeout=15)
        for prim in ['SerDir','SerFileRead','SerFileWrite','SerFileExists',
                     'SerMkDir','SerExecI64','SerExecStr','SerSymExists',
                     'SerSymList','SerMemInfo']:
            t.send_cmd(f'#include "C:/Home/{prim}.HC";')

        print("\n=== MAlloc / Free / MSize ===")
        tests = [
            ("alloc 1 byte non-null",
             'U8 *p=MAlloc(1);StrPrint(g_str,"%d",p!=0);Free(p);', '1'),
            ("alloc 1024 bytes non-null",
             'U8 *p=MAlloc(1024);StrPrint(g_str,"%d",p!=0);Free(p);', '1'),
            ("MSize matches alloc",
             'U8 *p=MAlloc(256);StrPrint(g_str,"%d",MSize(p)>=256);Free(p);', '1'),
            ("alloc 0 bytes",
             'U8 *p=MAlloc(0);StrPrint(g_str,"%d",p!=0);Free(p);', None),
            ("alloc+free 100x no crash",
             'I64 i;for(i=0;i<100;i++){U8*p=MAlloc(64);Free(p);}GStrAdd("ok");', 'ok'),
        ]
        for name, code, expect in tests:
            s, r = run_test(t, name, code, expect)
            results.append((name, s, r))

        print("\n=== String Functions ===")
        tests = [
            ("StrLen empty",      'StrPrint(g_str,"%d",StrLen(""));', '0'),
            ("StrLen hello",      'StrPrint(g_str,"%d",StrLen("hello"));', '5'),
            ("StrCmp equal",      'StrPrint(g_str,"%d",StrCmp("abc","abc"));', '0'),
            ("StrCmp less",       'StrPrint(g_str,"%d",StrCmp("a","b")<0);', '1'),
            ("StrCmp greater",    'StrPrint(g_str,"%d",StrCmp("b","a")>0);', '1'),
            ("StrCpy roundtrip",  'U8 buf[32];StrCpy(buf,"hello");GStrAdd(buf);', 'hello'),
            ("StrCat basic",      'U8 buf[32];StrCpy(buf,"foo");StrCat(buf,"bar");GStrAdd(buf);', 'foobar'),
        ]
        for name, code, expect in tests:
            s, r = run_test(t, name, code, expect)
            results.append((name, s, r))

        print("\n=== Integer / Math Edge Cases ===")
        tests = [
            ("I64 max value",
             'StrPrint(g_str,"%d",0x7FFFFFFFFFFFFFFF);', '9223372036854775807'),
            ("I64 min value",
             'StrPrint(g_str,"%d",-0x8000000000000000);', '-9223372036854775808'),
            ("I64 overflow wraps",
             'I64 x=0x7FFFFFFFFFFFFFFF;x++;StrPrint(g_str,"%d",x<0);', '1'),
            ("Abs positive",      'StrPrint(g_str,"%d",Abs(42));', '42'),
            ("Abs negative",      'StrPrint(g_str,"%d",Abs(-42));', '42'),
            ("Min/Max",
             'StrPrint(g_str,"%d %d",Min(3,7),Max(3,7));', '3 7'),
        ]
        for name, code, expect in tests:
            s, r = run_test(t, name, code, expect)
            results.append((name, s, r))

        print("\n=== Exception Behavior ===")
        tests = [
            ("throw survives",    "throw('Test');", None),
            ("div zero survives", 'I64 x=0;I64 y=1/x;GStrAdd("bad");', None),
            ("repl alive after",  'GStrAdd("alive");', 'alive'),
        ]
        for name, code, expect in tests:
            s, r = run_test(t, name, code, expect)
            results.append((name, s, r))

        # Write results to C:/AI/results/
        print("\nWriting results to TempleOS...")
        lines = ['name\tstatus\tresult\n']
        for name, status, result in results:
            lines.append(f'{name}\t{status}\t{result}\n')
        t.write_file(RESULTS_PATH, ''.join(lines).encode())
        print(f"  Saved to {RESULTS_PATH}")

        # Summary
        counts = {}
        for _, s, _ in results:
            counts[s] = counts.get(s, 0) + 1
        print(f"\nSummary: {counts}")

        t.unfreeze()

if __name__ == '__main__':
    main()
