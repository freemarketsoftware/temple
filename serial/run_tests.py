#!/usr/bin/env python3
"""
run_tests.py — Deploy and run the full TempleOS test suite via Agent

Loads snap1, deploys all test files to C:/AI/tests/, runs TestRunner.HC
through AgentLoop, reads and displays results.

Usage:
    sudo python3 serial/run_tests.py
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from agent import Agent

REPO_DIR     = os.path.join(os.path.dirname(__file__), '..', 'brain', 'templerepo')
RESULTS_PATH = 'C:/AI/results/TestResults.txt'
RUNNER_CMD   = '#include "C:/AI/tests/TestRunner.HC";'

# All tests safe for TestRunner (excludes OS-panicking tests:
#   TestIntDivZero, TestMallocEdge2/2b/2c/2d, TestMallocEdge3,
#   TestTasks, TestPCI, TestE1000*, TestDHCP, TestHTTPGet/Post,
#   TestICMP, TestArpPkt, TestIPv4Pkt, TestUDPPkt)
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
    'TestDirOps.HC',
    'TestF64Edge.HC',
    'TestQSort.HC',
    'TestKernelUtils.HC',
    'TestPointers.HC',
    'TestStrConv.HC',
    'TestRunner.HC',
]


def make_pre_deploy():
    """Return a pre_deploy(temple) callback that deploys all test files.

    Runs against the serial REPL before AgentLoop launches — the REPL is
    free at this point since AgentLoop hasn't been started yet.
    """
    def pre_deploy(t):
        t.mkdir('C:/AI')
        t.mkdir('C:/AI/tests')
        t.mkdir('C:/AI/results')
        print(f'Deploying {len(TEST_FILES)} test files to C:/AI/tests/...')
        ok = 0
        for fname in TEST_FILES:
            src = os.path.join(REPO_DIR, fname)
            if not os.path.exists(src):
                print(f'  [SKIP] {fname} — not found in templerepo')
                continue
            with open(src, 'rb') as f:
                content = f.read()
            t.write_file(f'C:/AI/tests/{fname}', content)
            print(f'  [OK]   {fname}  ({len(content)}b)')
            ok += 1
        print(f'Deployed {ok}/{len(TEST_FILES)} files.')
    return pre_deploy


def parse_results(raw):
    rows = []
    suite = '?'
    for line in raw.decode(errors='replace').splitlines():
        if not line.strip() or line.startswith('suite\t'):
            continue
        if line.startswith('# '):
            suite = line[2:].strip()
            continue
        parts = line.split('\t')
        name   = parts[0] if len(parts) > 0 else '?'
        status = parts[1] if len(parts) > 1 else '?'
        detail = parts[2] if len(parts) > 2 else ''
        rows.append((suite, name, status, detail.rstrip()))
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
    with Agent() as ag:
        print('Starting agent (loadvm snap1 + deploy + wait)...')
        if not ag.start(timeout=60, pre_deploy=make_pre_deploy()):
            print('FAIL: agent did not come online')
            sys.exit(1)
        print('Agent online.\n')

        print(f'Running TestRunner.HC (timeout 180s)...')
        ag.run(RUNNER_CMD, timeout=180)

        # AgentLoop holds the serial REPL while it runs; stop it first so
        # SerReplExe is free to handle read_file() calls.
        ag.stop()

        print('Reading results...')
        raw = ag.read_file(RESULTS_PATH, timeout=30)
        if not raw:
            print('ERROR: no results file — TestRunner may have crashed')
            sys.exit(1)

        rows = parse_results(raw)
        passed, failed, obs = print_results(rows)
        sys.exit(0 if failed == 0 else 1)


if __name__ == '__main__':
    main()
