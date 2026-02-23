#!/usr/bin/env python3
"""
run_tests.py — Deploy and run the full TempleOS test suite via TestRunner.HC

Deploys all test files to C:/AI/tests/, runs TestRunner.HC which writes
a single combined results file, then reads and displays results.

Usage:
    sudo python3 serial/run_tests.py
"""
import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

REPO_DIR = os.path.join(os.path.dirname(__file__), '..', 'brain', 'templerepo')
RESULTS_PATH = 'C:/AI/results/TestResults.txt'
RUNNER_PATH  = 'C:/AI/tests/TestRunner.HC'

TEST_FILES = [
    'TestMalloc.HC',
    'TestIntMath.HC',
    'TestStrings.HC',
    'TestFileIO.HC',
    'TestIntDiv.HC',
    'TestMallocEdge1.HC',
    'TestMallocEdge4.HC',
    'TestMallocEdge5.HC',
    'TestMallocEdge6.HC',
    'TestStrUtil.HC',
    'TestMath2.HC',
    'TestMemUtil.HC',
    'TestTypeConv.HC',
    'TestMemSet2.HC',
    'TestBitOps.HC',
    'TestException.HC',
    'TestStruct.HC',
    'TestI64Edge.HC',
    'TestGlobals.HC',
    'TestFmtSpec.HC',
    'TestFnPtr.HC',
    'TestDateTime.HC',
    'TestRunner.HC',
]


def wait_freeze(t, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if t.is_frozen(timeout=2):
            return True
        time.sleep(0.5)
    return False


def deploy_tests(t):
    print(f'Deploying {len(TEST_FILES)} test files to C:/AI/tests/...')
    ok = 0
    for fname in TEST_FILES:
        src = os.path.join(REPO_DIR, fname)
        dst = f'C:/AI/tests/{fname}'
        if not os.path.exists(src):
            print(f'  [SKIP] {fname} — not found in templerepo')
            continue
        with open(src, 'rb') as f:
            content = f.read()
        t.write_file(dst, content)
        print(f'  [OK]   {fname}  ({len(content)}b)')
        ok += 1
    print(f'Deployed {ok}/{len(TEST_FILES)} files.')
    return ok


def parse_results(raw):
    """Parse TSV results with # section headers. Returns list of (suite, name, status, detail)."""
    rows = []
    suite = '?'
    lines = raw.decode(errors='replace').splitlines()
    for line in lines:
        if not line.strip():
            continue
        if line.startswith('suite\t'):
            continue  # header
        if line.startswith('# '):
            suite = line[2:].strip()
            continue
        parts = line.split('\t')
        name   = parts[0] if len(parts) > 0 else '?'
        status = parts[1] if len(parts) > 1 else '?'
        detail = parts[2] if len(parts) > 2 else ''
        rows.append((suite, name, status, detail.rstrip('\n')))
    return rows


def print_results(rows):
    passed = failed = obs = 0
    cur_suite = None
    for suite, name, status, detail in rows:
        if suite != cur_suite:
            cur_suite = suite
            print(f'\n[{suite}]')
        if status == 'PASS':
            marker = '[PASS]'
            passed += 1
        elif status == 'OBS':
            marker = '[OBS] '
            obs += 1
        else:
            marker = '[FAIL]'
            failed += 1
        print(f'  {marker} {name}: {detail}')

    print()
    summary = f'{passed} passed, {failed} failed'
    if obs:
        summary += f', {obs} obs'
    print(f'Result: {summary}')
    return passed, failed, obs


def main():
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
            print('REPL ready.')
        else:
            print('REPL already running.')

        # Deploy all test files
        deploy_tests(t)

        # Run TestRunner
        print(f'\nRunning TestRunner (timeout 120s)...')
        t.send_cmd(f'#include "{RUNNER_PATH}";', timeout=120)

        # Read results
        print(f'Reading {RESULTS_PATH}...')
        raw = t.read_file(RESULTS_PATH, timeout=15)
        if not raw:
            print('ERROR: No results file found.')
            t.unfreeze()
            sys.exit(1)

        rows = parse_results(raw)
        passed, failed, obs = print_results(rows)

        t.unfreeze()
        sys.exit(0 if failed == 0 else 1)


if __name__ == '__main__':
    main()
