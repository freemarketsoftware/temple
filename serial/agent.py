#!/usr/bin/env python3
"""
agent.py — Python API for TempleOS AgentLoop.

High-level interface for executing HolyC from Python via the TCP
command/result channel.  Handles deployment, lifecycle, and recovery.

Usage:
    from agent import Agent

    with Agent() as ag:
        ag.start()
        print(ag.eval_i64('6*7'))                         # 42
        ag.define('I64 Sq(I64 x) { return x*x; }')
        print(ag.eval_i64('Sq(9)'))                       # 81
        print(f'uptime {ag.uptime():.1f}s')
"""

import os, sys, socket, subprocess, time

sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple, _qmon
from agent_server import (push_cmd, get_result, start_background,
                          _cmd_queue, _result_queue)

_AGENT_SRC = os.path.join(os.path.dirname(__file__),
                           '..', 'brain', 'templerepo', 'AgentLoop.HC')
_PORT = 8081


# ── helpers ───────────────────────────────────────────────────────────────────

def _server_alive(port: int) -> bool:
    s = socket.socket()
    s.settimeout(1)
    try:
        s.connect(('127.0.0.1', port))
        s.close()
        return True
    except Exception:
        return False


def _flush_queues():
    while not _cmd_queue.empty():
        _cmd_queue.get_nowait()
    while not _result_queue.empty():
        _result_queue.get_nowait()


# ── Agent ─────────────────────────────────────────────────────────────────────

class Agent:
    """
    TempleOS HolyC execution agent via TCP.

    Manages the full lifecycle of an AgentLoop session:
      • Load QEMU snapshot (clean VM state)
      • Start agent_server.py HTTP server
      • Deploy AgentLoop.HC via serial
      • Execute HolyC commands via GET /cmd / POST /result
      • Clean shutdown via EXIT

    All HolyC globals and functions defined in one run() call persist
    in subsequent calls — ExeFile runs in the same HolyC task.
    """

    def __init__(self, port: int = _PORT, snap: str = 'snap1'):
        self.port = port
        self.snap = snap
        self._t: Temple | None = None   # serial connection kept open
        self._live = False

    def __enter__(self):
        return self

    def __exit__(self, *_):
        if self._live:
            try:
                self.stop()
            except Exception:
                pass
        if self._t:
            try:
                self._t.close()
            except Exception:
                pass

    # ── lifecycle ─────────────────────────────────────────────────────────────

    def start(self, timeout: float = 60) -> bool:
        """
        Full start sequence:
          1. Flush stale queues
          2. Kill + restart agent_server
          3. Load QEMU snap (clean state)
          4. Deploy AgentLoop.HC via serial
          5. Poll PONG until online (up to timeout seconds)

        Returns True if online, False on timeout.
        """
        _flush_queues()

        if _server_alive(self.port):
            subprocess.run(['fuser', '-k', f'{self.port}/tcp'],
                           capture_output=True)
            time.sleep(0.4)
        start_background(self.port)
        time.sleep(0.5)

        _qmon(f'loadvm {self.snap}')
        time.sleep(8)

        self._t = Temple()
        self._t.connect()
        self._deploy()

        ok = self._wait_online(timeout=timeout)
        if ok:
            self._live = True
        return ok

    def stop(self):
        """Send EXIT and wait for AgentLoop to shut down cleanly."""
        if not self._live:
            return
        push_cmd('EXIT')
        self._live = False
        time.sleep(10)
        if self._t:
            self._t._drain(timeout=5)
            self._t._drain(timeout=5)

    def restart(self) -> bool:
        """EXIT current session, reload snapshot, redeploy."""
        if self._live:
            try:
                self.stop()
            except Exception:
                pass
        if self._t:
            try:
                self._t.close()
            except Exception:
                pass
            self._t = None
        return self.start()

    # ── command execution ─────────────────────────────────────────────────────

    def run(self, code: str, timeout: float = 20) -> str:
        """
        Execute a HolyC snippet and return its output.

        Output should be written via:
            StrPrint(g_agent_out, fmt, ...);
            CatPrint(g_agent_out, fmt, ...);

        Globals/functions defined here persist in future run() calls.
        Returns '' on timeout or if the snippet writes nothing.
        """
        push_cmd(code)
        result = get_result(timeout=timeout)
        if result is None:
            return ''
        return result.decode(errors='replace').rstrip()

    def define(self, code: str, timeout: float = 10):
        """
        Load HolyC definitions (functions, globals) into the agent environment.

        Definitions persist in subsequent run() calls.  Output is discarded.
        Example:
            ag.define('I64 Sq(I64 x) { return x*x; }')
            ag.eval_i64('Sq(7)')  # → 49
        """
        self.run(code, timeout=timeout)

    def eval_i64(self, expr: str, timeout: float = 20) -> int | None:
        """Evaluate a HolyC I64 expression, return Python int."""
        out = self.run(f'StrPrint(g_agent_out,"%lld\\n",({expr}));',
                       timeout=timeout)
        try:
            return int(out.strip())
        except (ValueError, AttributeError):
            return None

    def eval_f64(self, expr: str, timeout: float = 20) -> float | None:
        """Evaluate a HolyC F64 expression, return Python float."""
        out = self.run(f'StrPrint(g_agent_out,"%.10f\\n",({expr}));',
                       timeout=timeout)
        try:
            return float(out.strip())
        except (ValueError, AttributeError):
            return None

    def eval_str(self, expr: str, timeout: float = 20) -> str:
        """Evaluate a HolyC U8* expression, return Python str."""
        return self.run(f'StrPrint(g_agent_out,"%s\\n",({expr}));',
                        timeout=timeout).strip()

    def eval_hex(self, expr: str, timeout: float = 20) -> int | None:
        """Evaluate a HolyC expression, return Python int from hex output."""
        out = self.run(f'StrPrint(g_agent_out,"%X\\n",({expr}));',
                       timeout=timeout)
        try:
            return int(out.strip(), 16)
        except (ValueError, AttributeError):
            return None

    # ── system introspection ──────────────────────────────────────────────────

    def uptime(self) -> float:
        """Return TempleOS uptime in seconds (from tS global F64)."""
        return self.eval_f64('tS') or 0.0

    def free_mem(self) -> int | None:
        """
        Return approximate free memory in bytes.
        Reads Mem.raw_pages - Mem.raw_used from the TempleOS heap struct.
        Returns None if the symbol isn't accessible.
        """
        pages = self.eval_i64('Mem.raw_pages - Mem.raw_used')
        return pages * 4096 if pages is not None else None

    def task_list(self, timeout: float = 20) -> list[str]:
        """
        Walk the TempleOS task ring and return a list of task names.
        Stops after 64 tasks to avoid infinite loop on corrupted state.
        TempleOS CTask uses 'task_title' (U8*) for the display name.
        """
        code = (
            'CTask *_t=Fs; I64 _n=0;'
            'do{'
            '  CatPrint(g_agent_out,"%s\\n",_t->task_title);'
            '  _t=_t->next_task; _n++;'
            '}while(_t!=Fs && _n<64);'
        )
        out = self.run(code, timeout=timeout)
        return [l for l in out.splitlines() if l]

    def read_mem64(self, addr: int) -> int | None:
        """Read an I64 value from TempleOS virtual address."""
        return self.eval_hex(f'({addr})(I64*)[0]')

    def read_mem_bytes(self, addr: int, count: int,
                       timeout: float = 20) -> str:
        """Read `count` bytes from addr, return as hex pairs (space-separated)."""
        code = (
            f'I64 _i; for(_i=0;_i<{count};_i++){{'
            f'  StrPrint(g_agent_out+StrLen(g_agent_out),'
            f'    "%02X ",({addr}+_i)(U8*)[0]);'
            f'}}'
        )
        return self.run(code, timeout=timeout).strip()

    # ── file operations (via serial Temple connection) ────────────────────────

    def read_file(self, path: str, timeout: float = 30) -> bytes | None:
        """Read a TempleOS file, return raw bytes."""
        if self._t is None:
            return None
        return self._t.read_file(path, timeout=timeout)

    def write_file(self, path: str, data: bytes):
        """Write bytes to a TempleOS path."""
        if self._t:
            self._t.write_file(path, data)

    def list_dir(self, pattern: str) -> list[str]:
        """List directory entries matching a glob (e.g. 'C:/AI/*')."""
        if self._t:
            return self._t.list_dir(pattern)
        return []

    def mkdir(self, path: str):
        """Create a directory on TempleOS."""
        if self._t:
            self._t.mkdir(path)

    def read_debug_log(self) -> str | None:
        """Read AgentLoop's debug log (written to C:/AI/debug.txt on EXIT)."""
        data = self.read_file('C:/AI/debug.txt', timeout=5)
        return data.decode(errors='replace') if data else None

    # ── internal ──────────────────────────────────────────────────────────────

    def _deploy(self):
        """Write AgentLoop.HC to TempleOS and fire it via serial."""
        with open(_AGENT_SRC, 'rb') as f:
            content = f.read()

        # drain stale serial bytes
        self._t.s.settimeout(2)
        try:
            while True:
                if not self._t.s.recv(4096):
                    break
        except Exception:
            pass
        self._t.s.settimeout(None)

        # ensure REPL is up
        if not self._t.is_frozen(timeout=15):
            self._t._sendkey('#include "C:/Home/SerReplExe.HC"')
            time.sleep(1)
            self._t._sendkey('Dir;')
            deadline = time.time() + 25
            while time.time() < deadline:
                if self._t.is_frozen(timeout=2):
                    break
                time.sleep(0.5)

        self._t.mkdir('C:/AI')
        self._t.write_file('C:/AI/AgentLoop.HC', content)
        self._t.s.sendall(b'#include "C:/AI/AgentLoop.HC";\n')

    def _wait_online(self, timeout: float = 60, poll: float = 5.0) -> bool:
        """
        Poll PONG until the agent responds or deadline is reached.

        Each iteration pushes one PONG command and waits up to `poll` seconds.
        If multiple iterations fire before the first result arrives, stale PONG
        commands accumulate in _cmd_queue.  After going online we flush both
        queues and allow 2.5 s for any already-fetched PONG to complete, then
        flush again — leaving the queues clean for the caller.
        """
        deadline = time.time() + timeout
        while time.time() < deadline:
            push_cmd('CatPrint(g_agent_out,"PONG\\n");')
            r = get_result(timeout=poll)
            if r is not None and b'PONG' in r:
                # Drain any stale PONG commands sitting in the cmd queue
                _flush_queues()
                # Give AgentLoop time to finish any already-fetched PONG,
                # then flush the result that arrives for it.
                time.sleep(2.5)
                _flush_queues()
                return True
        return False
