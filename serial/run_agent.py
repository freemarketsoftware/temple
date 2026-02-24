#!/usr/bin/env python3
"""
run_agent.py — Deploy AgentLoop.HC and open an interactive session.

Usage:
    sudo python3 serial/run_agent.py

Starts agent_server.py on port 8081, deploys AgentLoop.HC via serial
(inside SerReplExe's proven networking context), then drops into an
interactive loop where you type HolyC and see the output.

Commands write to g_agent_out[] via CatPrint(g_agent_out,...).
Type EXIT to stop the agent loop.
"""
import sys, os, time, socket, subprocess
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple
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


def ensure_agent_server():
    # Kill any stale process holding the port — its in-memory queue is
    # unreachable from this process, so we always start fresh in-process.
    if server_running(PORT):
        print(f'Killing stale server on :{PORT}...')
        subprocess.run(['fuser', '-k', f'{PORT}/tcp'],
                       capture_output=True)
        time.sleep(0.4)
    print(f'Starting agent_server on :{PORT}...')
    start_background(PORT)
    time.sleep(0.5)
    print('Agent server started.')


def wait_frozen(t, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if t.is_frozen(timeout=2):
            return True
        time.sleep(0.5)
    return False


def drain_serial(t, timeout=2):
    """Discard any stale bytes sitting in the serial socket buffer.
    Prevents a leftover EXIT from a previous run being consumed by a freshly
    started SerReplExe and causing it to immediately quit."""
    t.s.settimeout(timeout)
    try:
        while True:
            chunk = t.s.recv(4096)
            if not chunk:
                break
    except Exception:
        pass
    t.s.settimeout(None)


def deploy_agent(t):
    with open(SRC, 'rb') as f:
        content = f.read()

    # Drain stale serial bytes from previous runs
    drain_serial(t)

    # Ensure REPL is running so we can use write_file
    if not t.is_frozen(timeout=3):
        print('Starting REPL...')
        t._sendkey('#include "C:/Home/SerReplExe.HC"')
        time.sleep(1)
        t._sendkey('Dir;')
        if not wait_frozen(t, timeout=20):
            print('ERROR: REPL did not start.')
            sys.exit(1)

    print('Deploying AgentLoop.HC...')
    t.mkdir('C:/AI')
    t.write_file('C:/AI/AgentLoop.HC', content)

    # Fire AgentLoop via SerReplExe serial (fire-and-forget).
    # Do NOT unfreeze first — AgentLoop runs inside SerReplExe's execution
    # context, which is the proven networking context (same as TestHTTPPost).
    # SerReplExe blocks until AgentLoop returns (on EXIT).
    # The CAFEBABE response arrives only after EXIT; we drain it at shutdown.
    print('Launching AgentLoop via serial...')
    t.s.sendall(b'#include "C:/AI/AgentLoop.HC";\n')
    # AgentLoop is now running: NIC init + ARP Sleep(2000) + poll loop


def send_recv(cmd, timeout=15):
    push_cmd(cmd)
    result = get_result(timeout=timeout)
    if result is None:
        return '(timeout)'
    return result.decode(errors='replace').rstrip()


def main():
    ensure_agent_server()

    print()
    print('+' + '-'*54 + '+')
    print('|  TempleOS Agent — interactive HolyC over TCP          |')
    print('|  Write output with: CatPrint(g_agent_out, "...");     |')
    print('|  EXIT to quit                                          |')
    print('+' + '-'*54 + '+')
    print()

    with Temple() as t:
        deploy_agent(t)

        # NIC init + ARP takes ~4s, first GET/cmd loop takes another ~2.5s
        print('Waiting for agent online (~10s)...')
        time.sleep(10)

        # Ping — push to queue, wait up to 20s for result
        result = send_recv('CatPrint(g_agent_out, "PONG\\n");', timeout=20)
        if 'PONG' in result:
            print(f'Agent online.')
        else:
            print(f'WARNING: no PONG response ({result!r}) — continuing anyway')
        print()

        while True:
            try:
                cmd = input('hc> ').strip()
            except (EOFError, KeyboardInterrupt):
                cmd = 'EXIT'

            if not cmd:
                continue

            if cmd.upper() == 'EXIT':
                push_cmd('EXIT')
                time.sleep(3)  # wait for AgentLoop to process EXIT and return
                # Drain the CAFEBABE that SerReplExe sends after AgentLoop exits
                t._drain(timeout=3)
                break

            result = send_recv(cmd)
            if result:
                print(result)


if __name__ == '__main__':
    main()
