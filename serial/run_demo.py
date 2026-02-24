#!/usr/bin/env python3
"""
run_demo.py — TempleOS Network Stack Demo runner.

Usage:
    sudo python3 serial/run_demo.py

Ensures a Python HTTP server is running on port 8080, then deploys
Demo.HC to the TempleOS VM and prints the live demo output.
"""
import sys, os, time, socket, subprocess
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

DEMO_SRC = os.path.join(os.path.dirname(__file__), '..', 'brain', 'templerepo', 'Demo.HC')
RESULTS  = 'C:/AI/results/Demo.txt'
BORDER   = '+' + '-' * 52 + '+'

def http_server_running():
    s = socket.socket()
    s.settimeout(1)
    try:
        s.connect(('127.0.0.1', 8080))
        s.close()
        return True
    except Exception:
        return False

def ensure_http_server():
    if http_server_running():
        print('HTTP server already running on port 8080.')
        return
    print('Starting Python HTTP server on port 8080 (/tmp)...')
    subprocess.Popen(
        ['python3', '-m', 'http.server', '8080'],
        cwd='/tmp',
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(1.5)
    if not http_server_running():
        print('ERROR: HTTP server failed to start on port 8080.')
        sys.exit(1)
    print('HTTP server started.')

def wait_frozen(t, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if t.is_frozen(timeout=2):
            return True
        time.sleep(0.5)
    return False

def main():
    ensure_http_server()

    with open(DEMO_SRC, 'rb') as f:
        content = f.read()

    print()
    print(BORDER)
    print('|  TempleOS Network Stack Demo                       |')
    print('|  NIC init -> ARP -> ICMP ping -> HTTP GET over TCP |')
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

        print('Deploying Demo.HC...')
        t.write_file('C:/AI/tests/Demo.HC', content)

        print('Running  (3x Sleep(2000) inside — takes ~8s)...')
        t.send_cmd('#include "C:/AI/tests/Demo.HC";')

        raw = t.read_file(RESULTS, timeout=25)
        if not raw:
            print('\nERROR: No results file written.')
            print('Check that the e1000 NIC is available and HTTP server is up.')
            t.unfreeze()
            sys.exit(1)

        text = raw.decode(errors='replace')

        print()
        print(BORDER)
        for line in text.splitlines():
            print('  ' + line)
        print(BORDER)
        print()

        t.unfreeze()

if __name__ == '__main__':
    main()
