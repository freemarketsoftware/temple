#!/usr/bin/env python3
"""
agent_repl.py — Interactive HolyC REPL backed by TempleOS AgentLoop.

Usage:
    sudo python3 serial/agent_repl.py [--no-snap]

Features:
  • Execute HolyC interactively — globals/functions persist between lines
  • Multi-line input: end a line with \\ for continuation; { auto-continues
  • @file.HC          load and execute a host-side HolyC file
  • Built-in commands (prefix :):
      :sys            TempleOS system info (uptime, free mem, tasks)
      :tasks          list all running TempleOS tasks
      :ls  [path]     list directory (default C:/AI/*)
      :cat <path>     read + print a TempleOS file
      :hex <addr>     dump 64 bytes from a virtual address
      :debug          print AgentLoop debug log
      :history        print command history
      :reset          restart AgentLoop (clears all JIT definitions)
      :quit / EXIT    exit REPL
"""

import os, sys, time, readline, argparse, textwrap

sys.path.insert(0, os.path.dirname(__file__))
from agent import Agent

# ── ANSI colours ──────────────────────────────────────────────────────────────
_BOLD  = '\033[1m'
_DIM   = '\033[2m'
_GREEN = '\033[32m'
_CYAN  = '\033[36m'
_YELLOW= '\033[33m'
_RED   = '\033[31m'
_RESET = '\033[0m'

def _c(color, text):
    return f'{color}{text}{_RESET}'

def _banner():
    print(_c(_BOLD, '┌' + '─'*54 + '┐'))
    print(_c(_BOLD, '│') + _c(_CYAN, '  TempleOS HolyC REPL  ') +
          _c(_DIM, '(via AgentLoop TCP)') + ' ' * 10 + _c(_BOLD, '│'))
    print(_c(_BOLD, '│') + _c(_DIM, '  globals/functions persist across commands          ') + _c(_BOLD, '│'))
    print(_c(_BOLD, '│') + _c(_DIM, '  :sys :tasks :ls :cat :hex :debug :reset :quit     ') + _c(_BOLD, '│'))
    print(_c(_BOLD, '│') + _c(_DIM, '  @file.HC to load a host HolyC file                ') + _c(_BOLD, '│'))
    print(_c(_BOLD, '└' + '─'*54 + '┘'))
    print()

# ── readline history ──────────────────────────────────────────────────────────
_HIST = os.path.expanduser('~/.hc_repl_history')

def _setup_readline():
    try:
        readline.read_history_file(_HIST)
    except FileNotFoundError:
        pass
    readline.set_history_length(500)
    import atexit
    atexit.register(readline.write_history_file, _HIST)

def _history_lines() -> list[str]:
    return [readline.get_history_item(i + 1)
            for i in range(readline.get_current_history_length())]

# ── multi-line input ──────────────────────────────────────────────────────────
def _read_cmd(prompt='hc> ') -> str | None:
    """
    Read one logical command, handling:
      - Backslash continuation
      - Auto-continuation when open braces exceed close braces
      - :commands  returned verbatim
      - EOF / Ctrl-C → None
    """
    try:
        line = input(prompt)
    except (EOFError, KeyboardInterrupt):
        return None

    if not line.strip():
        return ''

    # :commands and @file are always single-line
    if line.strip().startswith(':') or line.strip().startswith('@'):
        return line.strip()

    parts = [line]

    # continuation: explicit backslash or unbalanced braces
    while True:
        full = '\n'.join(parts)
        depth = full.count('{') - full.count('}')
        cont  = parts[-1].rstrip().endswith('\\')

        if not cont and depth <= 0:
            break

        # strip trailing backslash from last part
        if cont:
            parts[-1] = parts[-1].rstrip()[:-1]

        try:
            nxt = input('...> ')
        except (EOFError, KeyboardInterrupt):
            break
        parts.append(nxt)

    return '\n'.join(parts)

# ── built-in commands ─────────────────────────────────────────────────────────

def _cmd_sys(ag: Agent):
    uptime = ag.uptime()
    h, rem = divmod(int(uptime), 3600)
    m, s   = divmod(rem, 60)
    upstr  = f'{h}h {m}m {s}s' if h else (f'{m}m {s}s' if m else f'{s}s')

    free = ag.free_mem()
    if free is not None:
        free_str = f'{free // (1024*1024)} MB ({free // 4096:,} pages)'
    else:
        free_str = '(unavailable)'

    print(_c(_BOLD, '\n=== TempleOS System Info ==='))
    print(f'  Uptime : {_c(_CYAN, upstr)}  ({uptime:.2f}s)')
    print(f'  FreeMem: {_c(_CYAN, free_str)}')
    print()

def _cmd_tasks(ag: Agent):
    tasks = ag.task_list()
    print(_c(_BOLD, f'\n=== Tasks ({len(tasks)}) ==='))
    for name in tasks:
        print(f'  {_c(_GREEN, name)}')
    print()

def _cmd_ls(ag: Agent, path: str):
    pattern = path or 'C:/AI/*'
    if '*' not in pattern:
        pattern = pattern.rstrip('/') + '/*'
    entries = ag.list_dir(pattern)
    print(_c(_BOLD, f'\n{pattern}'))
    if entries:
        for e in entries:
            print(f'  {_c(_CYAN, e)}')
    else:
        print(_c(_DIM, '  (empty)'))
    print()

def _cmd_cat(ag: Agent, path: str):
    if not path:
        print(_c(_RED, 'Usage: :cat <path>'))
        return
    data = ag.read_file(path)
    if data is None:
        print(_c(_RED, f'Cannot read: {path}'))
        return
    print(_c(_BOLD, f'\n--- {path} ---'))
    print(data.decode(errors='replace'))
    print(_c(_BOLD, f'--- end ({len(data)} bytes) ---'))
    print()

def _cmd_hex(ag: Agent, arg: str):
    if not arg:
        print(_c(_RED, 'Usage: :hex <address>'))
        return
    try:
        addr = int(arg, 16) if arg.startswith('0x') else int(arg, 16)
    except ValueError:
        print(_c(_RED, f'Bad address: {arg}'))
        return

    out = ag.read_mem_bytes(addr, 64)
    if not out:
        print(_c(_RED, 'Read failed (timeout or bad address)'))
        return

    # format as xxd-style hex dump
    raw = out.split()
    print(_c(_BOLD, f'\n--- memory @ 0x{addr:016X} ---'))
    for row in range(0, len(raw), 16):
        chunk = raw[row:row + 16]
        addr_str = f'{addr + row:016X}'
        hex_str  = ' '.join(chunk)
        # ascii side
        chars = ''.join(
            chr(int(b, 16)) if 0x20 <= int(b, 16) < 0x7F else '.'
            for b in chunk
        )
        print(f'  {_c(_DIM, addr_str)}  {hex_str:<47}  {_c(_DIM, chars)}')
    print()

def _cmd_debug(ag: Agent):
    log = ag.read_debug_log()
    if log:
        print(_c(_BOLD, '\n--- AgentLoop debug.txt ---'))
        print(log.rstrip())
        print(_c(_BOLD, '--- end ---'))
    else:
        print(_c(_DIM, '(debug.txt not available — agent still running)'))
    print()

def _cmd_history(lines: list[str]):
    print(_c(_BOLD, '\n--- History ---'))
    for i, l in enumerate(lines[-20:], 1):
        print(f'  {_c(_DIM, str(i)):>4}  {l}')
    print()

def _cmd_load_file(ag: Agent, path: str):
    try:
        with open(path, 'r', errors='replace') as f:
            code = f.read()
    except FileNotFoundError:
        print(_c(_RED, f'File not found: {path}'))
        return
    print(_c(_DIM, f'[loading {path} — {len(code)} bytes]'))
    out = ag.run(code, timeout=30)
    if out:
        print(_c(_GREEN, out))

# ── dispatch ──────────────────────────────────────────────────────────────────

def _dispatch(line: str, ag: Agent, hist: list[str]) -> bool:
    """
    Handle one logical command line.
    Returns False when the user wants to quit.
    """
    if not line:
        return True

    # @ file load
    if line.startswith('@'):
        _cmd_load_file(ag, line[1:].strip())
        return True

    # built-in :commands
    if line.startswith(':'):
        parts = line[1:].split(None, 1)
        cmd   = parts[0].lower()
        arg   = parts[1].strip() if len(parts) > 1 else ''

        if cmd in ('quit', 'exit', 'q'):
            return False
        elif cmd == 'sys':
            _cmd_sys(ag)
        elif cmd == 'tasks':
            _cmd_tasks(ag)
        elif cmd == 'ls':
            _cmd_ls(ag, arg)
        elif cmd == 'cat':
            _cmd_cat(ag, arg)
        elif cmd == 'hex':
            _cmd_hex(ag, arg)
        elif cmd == 'debug':
            _cmd_debug(ag)
        elif cmd == 'history':
            _cmd_history(hist)
        elif cmd == 'reset':
            print(_c(_YELLOW, 'Restarting AgentLoop...'))
            ok = ag.restart()
            if ok:
                print(_c(_GREEN, 'Agent online.'))
            else:
                print(_c(_RED, 'Restart failed — agent offline.'))
        else:
            print(_c(_RED, f'Unknown command: :{cmd}'))
        return True

    # EXIT keyword (keep backward compat with run_agent.py habit)
    if line.strip().upper() == 'EXIT':
        return False

    # normal HolyC — execute and show output
    t0  = time.time()
    out = ag.run(line, timeout=20)
    dt  = time.time() - t0

    if out:
        print(_c(_GREEN, out))
    print(_c(_DIM, f'({dt:.2f}s)'))
    return True

# ── main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='TempleOS HolyC REPL')
    parser.add_argument('--no-snap', action='store_true',
                        help='Skip loadvm — assume VM already at snap1 state')
    args = parser.parse_args()

    _setup_readline()
    _banner()

    ag = Agent()

    if args.no_snap:
        # Assume VM is ready; just start the HTTP server and deploy
        print('Skipping loadvm (--no-snap)...')
        from agent_server import start_background
        import subprocess, socket as _s
        if not _s.socket().__class__:  # always
            pass
        from agent import _server_alive, _flush_queues
        _flush_queues()
        from agent_server import start_background
        start_background(ag.port)
        time.sleep(0.5)
        ag._t = __import__('temple').Temple()
        ag._t.connect()
        ag._deploy()
        ok = ag._wait_online(timeout=60)
    else:
        print('Starting agent (loadvm snap1 + deploy + wait)...')
        ok = ag.start(timeout=60)

    if not ok:
        print(_c(_RED, 'ERROR: Agent did not come online.'))
        sys.exit(1)

    print(_c(_GREEN, 'Agent online.  Type HolyC or :help for commands.\n'))

    history: list[str] = []

    try:
        while True:
            line = _read_cmd('hc> ')
            if line is None:          # EOF / Ctrl-C
                break
            if not line:
                continue
            history.append(line)
            if not _dispatch(line, ag, history):
                break
    except KeyboardInterrupt:
        print()

    print(_c(_YELLOW, '\nSending EXIT to AgentLoop...'))
    ag.stop()
    print(_c(_GREEN, 'Done.'))


if __name__ == '__main__':
    main()
