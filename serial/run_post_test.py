#!/usr/bin/env python3
"""
run_post_test.py — runner for TestHTTPPost.HC

Usage:
    sudo python3 serial/run_post_test.py

Starts agent_server.py on port 8081 if not already running, deploys
TestHTTPPost.HC to the TempleOS VM, and prints the results.
"""
import sys, os, time, socket, subprocess, threading
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

SRC     = os.path.join(os.path.dirname(__file__), '..', 'brain', 'templerepo', 'TestHTTPPost.HC')
RESULTS = 'C:/AI/results/TestHTTPPost.txt'
PORT    = 8081
BORDER  = '+' + '-' * 52 + '+'


def server_running(port):
    s = socket.socket()
    s.settimeout(1)
    try:
        s.connect(('127.0.0.1', port))
        s.close()
        return True
    except Exception:
        return False


def ensure_agent_server():
    if server_running(PORT):
        print(f'Agent server already running on port {PORT}.')
        return
    print(f'Starting agent_server.py on port {PORT}...')
    script = os.path.join(os.path.dirname(__file__), 'agent_server.py')
    subprocess.Popen(
        [sys.executable, script, str(PORT)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(1.5)
    if not server_running(PORT):
        print(f'ERROR: agent_server.py failed to start on port {PORT}.')
        sys.exit(1)
    print('Agent server started.')


def wait_frozen(t, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if t.is_frozen(timeout=2):
            return True
        time.sleep(0.5)
    return False


def main():
    ensure_agent_server()

    with open(SRC, 'rb') as f:
        content = f.read()

    print()
    print(BORDER)
    print('|  TestHTTPPost — HTTP POST over TCP                  |')
    print('|  SYN → SYN-ACK → ACK+POST → 200 + ECHO response   |')
    print(BORDER)
    print()

    with Temple() as t:
        if not t.is_frozen(timeout=3):
            print('Starting REPL...')
            t._sendkey('#include "C:/Home/SerReplExe.HC"')
            time.sleep(1)
            t._sendkey('Dir;')
            if not wait_frozen(t, timeout=20):
                print('ERROR: REPL did not start.')
                sys.exit(1)

        print('Deploying TestHTTPPost.HC...')
        t.write_file('C:/AI/tests/TestHTTPPost.HC', content)

        print('Running (2x Sleep(2000) inside — takes ~5s)...')
        t.send_cmd('#include "C:/AI/tests/TestHTTPPost.HC";')

        raw = t.read_file(RESULTS, timeout=20)
        if not raw:
            print('\nERROR: No results file written.')
            print('Is agent_server.py running on port 8081?')
            t.unfreeze()
            sys.exit(1)

        text = raw.decode(errors='replace')
        lines = [l for l in text.splitlines() if not l.startswith('#')]
        passed = sum(1 for l in lines if '\tPASS\t' in l or l.endswith('\tPASS'))
        failed = sum(1 for l in lines if '\tFAIL\t' in l or l.endswith('\tFAIL'))

        print()
        print(BORDER)
        for line in text.splitlines():
            print('  ' + line)
        print(BORDER)
        print()
        print(f'  {passed} pass  {failed} fail  (of {passed+failed} tests)')
        print()

        t.unfreeze()

        if failed:
            sys.exit(1)


if __name__ == '__main__':
    main()
