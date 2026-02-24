#!/usr/bin/env python3
"""
test_agent.py — Non-interactive smoke test for AgentLoop.HC

Usage:
    sudo python3 serial/test_agent.py

Deploys AgentLoop.HC, waits for it to come online, runs 3 quick tests,
then sends EXIT.  Reports PASS / FAIL.
"""
import sys, os, time, socket, subprocess
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple, _qmon
from agent_server import push_cmd, get_result, start_background

SRC  = os.path.join(os.path.dirname(__file__), '..', 'brain', 'templerepo', 'AgentLoop.HC')
PORT = 8081


def server_running(port):
    s = socket.socket()
    s.settimeout(1)
    try:
        s.connect(('127.0.0.1', port))
        s.close()
        return True
    except Exception:
        return False


def ensure_server():
    if server_running(PORT):
        subprocess.run(['fuser', '-k', f'{PORT}/tcp'], capture_output=True)
        time.sleep(0.4)
    start_background(PORT)
    time.sleep(0.5)


def wait_frozen(t, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if t.is_frozen(timeout=2):
            return True
        time.sleep(0.5)
    return False


def drain_serial(t, timeout=2):
    t.s.settimeout(timeout)
    try:
        while True:
            chunk = t.s.recv(4096)
            if not chunk:
                break
    except Exception:
        pass
    t.s.settimeout(None)


def send_recv(cmd, timeout=20):
    push_cmd(cmd)
    result = get_result(timeout=timeout)
    if result is None:
        return None
    return result.decode(errors='replace').rstrip()


def main():
    # Load snap1 first — kills any lingering AgentLoop instances and gives a
    # clean TempleOS state.  Temple() is opened AFTER this so the socket
    # connects to the freshly restored VM.
    import os as _os
    print(f'[main] entry PID={_os.getpid()}')

    # Flush any stale data from previous runs before starting fresh
    from agent_server import _cmd_queue, _result_queue
    while not _cmd_queue.empty():
        stale = _cmd_queue.get_nowait()
        print(f'[main] flushed stale cmd: {stale!r}')
    while not _result_queue.empty():
        stale = _result_queue.get_nowait()
        print(f'[main] flushed stale result: {stale!r}')

    print('Loading snap1...')
    _qmon('loadvm snap1')
    time.sleep(8)

    ensure_server()
    print('Agent server started.')

    with open(SRC, 'rb') as f:
        content = f.read()

    passed = 0
    failed = 0

    with Temple() as t:
        # ── Deploy ────────────────────────────────────────────────────────────
        drain_serial(t)

        if not t.is_frozen(timeout=15):
            print('Starting REPL...')
            t._sendkey('#include "C:/Home/SerReplExe.HC"')
            time.sleep(1)
            t._sendkey('Dir;')
            if not wait_frozen(t, timeout=25):
                print('FAIL: REPL did not start')
                sys.exit(1)

        print('Deploying AgentLoop.HC...')
        t.mkdir('C:/AI')
        t.write_file('C:/AI/AgentLoop.HC', content)

        # Fire via serial inside SerReplExe context (proven networking path)
        print('Launching AgentLoop via serial...')
        t.s.sendall(b'#include "C:/AI/AgentLoop.HC";\n')

        # ── Tests ─────────────────────────────────────────────────────────────
        # Test 1 doubles as "wait for online" — 60s timeout covers NIC init + ARP
        print('Waiting for agent online (up to 60s)...')

        # Test 1: PONG
        r = send_recv('CatPrint(g_agent_out,"PONG\\n");', timeout=60)
        if r and 'PONG' in r:
            print(f'  PASS  PONG: {r!r}')
            passed += 1
        else:
            print(f'  FAIL  PONG: {r!r}')
            failed += 1

        # Test 2: arithmetic (I64 via StrPrint then CatPrint)
        r = send_recv('I64 n=6*7; StrPrint(g_agent_out,"%d\\n",n);', timeout=20)
        if r and '42' in r:
            print(f'  PASS  arithmetic: {r!r}')
            passed += 1
        else:
            print(f'  FAIL  arithmetic: {r!r}')
            failed += 1

        # Test 3: string output (StrPrint, same pattern as arithmetic)
        r = send_recv('StrPrint(g_agent_out,"hello world\\n");', timeout=20)
        if r and 'hello world' in r:
            print(f'  PASS  string: {r!r}')
            passed += 1
        else:
            print(f'  FAIL  string: {r!r}')
            failed += 1

        # ── Shutdown ──────────────────────────────────────────────────────────
        push_cmd('EXIT')
        time.sleep(10)       # AgentLoop needs up to ~5s to GET EXIT + write debug.txt
        t._drain(timeout=5)  # result CAFEBABE from #include AgentLoop (empty)
        t._drain(timeout=5)  # OK CAFEBABE from #include AgentLoop

        # ── Debug log ─────────────────────────────────────────────────────────
        try:
            dbg = t.read_file('C:/AI/debug.txt', timeout=5)
            if dbg:
                print()
                print('=== debug.txt ===')
                print(dbg.decode(errors='replace').rstrip())
                print('=================')
        except Exception:
            pass

    print()
    print(f'Result: {passed} pass  {failed} fail')
    import os as _os
    print(f'[main] exit PID={_os.getpid()}')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
