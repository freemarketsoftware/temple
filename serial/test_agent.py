#!/usr/bin/env python3
"""
test_agent.py — Non-interactive smoke test for AgentLoop.HC

Usage:
    sudo python3 serial/test_agent.py

Deploys AgentLoop.HC, waits for it to come online, runs 3 quick tests,
then sends EXIT.  Reports PASS / FAIL.
"""
import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
from agent import Agent

SRC = os.path.join(os.path.dirname(__file__), '..', 'brain', 'templerepo', 'AgentLoop.HC')


def main():
    passed = 0
    failed = 0

    with Agent() as ag:
        print('Starting agent (loadvm snap1 + deploy + wait)...')
        if not ag.start(timeout=60):
            print('FAIL: agent did not come online')
            sys.exit(1)
        print('Agent online.')

        # Test 1: PONG
        r = ag.run('CatPrint(g_agent_out,"PONG\\n");', timeout=20)
        if 'PONG' in r:
            print(f'  PASS  PONG: {r!r}')
            passed += 1
        else:
            print(f'  FAIL  PONG: {r!r}')
            failed += 1

        # Test 2: arithmetic
        r = ag.run('I64 n=6*7; StrPrint(g_agent_out,"%d\\n",n);', timeout=20)
        if '42' in r:
            print(f'  PASS  arithmetic: {r!r}')
            passed += 1
        else:
            print(f'  FAIL  arithmetic: {r!r}')
            failed += 1

        # Test 3: string output
        r = ag.run('StrPrint(g_agent_out,"hello world\\n");', timeout=20)
        if 'hello world' in r:
            print(f'  PASS  string: {r!r}')
            passed += 1
        else:
            print(f'  FAIL  string: {r!r}')
            failed += 1

        # Test 4: uptime (F64 via agent helper)
        up = ag.uptime()
        if up is not None and up > 0:
            print(f'  PASS  uptime: {up:.2f}s')
            passed += 1
        else:
            print(f'  FAIL  uptime: {up!r}')
            failed += 1

        # Test 5: eval_i64
        n = ag.eval_i64('100 + 23')
        if n == 123:
            print(f'  PASS  eval_i64: {n}')
            passed += 1
        else:
            print(f'  FAIL  eval_i64: {n!r}')
            failed += 1

        # Test 6: persistent define + call
        ag.define('I64 AgSq(I64 x) { return x*x; }')
        sq = ag.eval_i64('AgSq(7)')
        if sq == 49:
            print(f'  PASS  define+call: AgSq(7)={sq}')
            passed += 1
        else:
            print(f'  FAIL  define+call: AgSq(7)={sq!r}')
            failed += 1

        # Test 7: task count (at least 1 task must be running)
        tasks = ag.task_list()
        # Raw count probe using Fs (current task) as ring entry point
        count_code = (
            'CTask *_tc=Fs; I64 _nc=0;'
            'do{_nc++;_tc=_tc->next_task;}while(_tc!=Fs && _nc<64);'
            'StrPrint(g_agent_out,"%lld\\n",_nc);'
        )
        n_str = ag.run(count_code, timeout=20)
        try:
            n = int(n_str.strip())
        except (ValueError, AttributeError):
            n = None
        if tasks or (n is not None and n > 0):
            print(f'  PASS  tasks: count={n} names={tasks}')
            passed += 1
        else:
            print(f'  FAIL  tasks: count={n!r} names={tasks!r}')
            failed += 1

        # debug log
        ag.stop()
        try:
            dbg = ag.read_debug_log()
            if dbg:
                print()
                print('=== debug.txt ===')
                print(dbg.rstrip())
                print('=================')
        except Exception:
            pass

    print()
    print(f'Result: {passed} pass  {failed} fail')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
