"""
temple.py — Python interface to TempleOS over serial (CAFEBABE protocol)

Usage:
    from temple import Temple

    with Temple() as t:
        t.freeze()              # load SerReplExe, wait for REPL_READY
        files = t.list_dir("C:/Home/*")
        content = t.read_file("C:/Home/SerProto.HC")
        t.write_file("C:/Home/test.HC", b'UartPrint("hello\\n");')
        t.unfreeze()

Protocol:
    - Terminator: \\x04\\xCA\\xFE\\xBA\\xBE\\x04\\xFA\\xCE  (CAFEBABE)
    - Every command produces two TERM sequences:
        1. Primitive payload + TERM
        2. SerReplExe OK + TERM
    - drain() always called after every command to consume the trailing OK
    - SerFileWrite uses single \\x04 as ready signal (host-to-temple direction)
"""

import socket
import struct
import time
import subprocess

SOCK = '/tmp/temple-serial.sock'
QMON = '/tmp/qmon.sock'
TERM = b'\x04\xCA\xFE\xBA\xBE\x04\xFA\xCE'

# Custom primitives not in snap1 — written to VM by freeze()
_SERPRINT_HC = (
    b'U8 g_sp[4096];\n'
    b'U0 SerPrint(U8 *s){SerSend(s);}\n'
    b'U0 SerFmt(U8 *fmt,I64 a,I64 b){StrPrint(g_sp,fmt,a,b);SerSend(g_sp);}\n'
)

class TempleException(Exception):
    """Raised when TempleOS throws an unhandled exception during exec."""
    pass


def _decode_except_ch(hex_str):
    """Decode a TempleOS exception code from hex to string.
    Exception codes are I64 values with up to 8 ASCII chars packed little-endian.
    e.g. 'Compiler' -> 0x72656C69706D6F43 -> 'Compiler'
    """
    try:
        n = int(hex_str, 16)
        return struct.pack('<q', n).rstrip(b'\x00').decode('ascii', errors='replace')
    except Exception:
        return hex_str


BANNED_FILES = {
    'C:/Adam/AutoComplete/ACDefs.DATA',
    'C:/Adam/AutoComplete/ACWords.DATA.Z',
}


class Temple:
    def __init__(self, sock_path=SOCK, timeout=20):
        self.sock_path = sock_path
        self.default_timeout = timeout
        self.s = None

    def __enter__(self):
        self.connect()
        return self

    def __exit__(self, *_):
        self.close()

    def connect(self):
        self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.s.connect(self.sock_path)

    def close(self):
        if self.s:
            self.s.close()
            self.s = None

    # -------------------------------------------------------------------------
    # Low-level protocol
    # -------------------------------------------------------------------------

    def _recv_until_term(self, timeout=None):
        """Read from socket until TERM sequence found. Returns (content, remainder)."""
        if timeout is None:
            timeout = self.default_timeout
        buf = b''
        deadline = time.time() + timeout
        self.s.settimeout(1.0)
        while time.time() < deadline:
            try:
                chunk = self.s.recv(512)
                if chunk:
                    buf += chunk
                    if TERM in buf:
                        idx = buf.index(TERM)
                        return buf[:idx], buf[idx + len(TERM):]
            except socket.timeout:
                pass
        return None, b''

    def _drain(self, timeout=3):
        """Consume trailing OK+TERM from SerReplExe."""
        self._recv_until_term(timeout=timeout)

    def send_cmd(self, cmd, timeout=None):
        """Send a command to SerReplExe, return the response payload."""
        if timeout is None:
            timeout = self.default_timeout
        self.s.sendall((cmd + '\n').encode())
        content, _ = self._recv_until_term(timeout=timeout)
        self._drain()
        return content

    def is_frozen(self, timeout=3):
        """
        Check if TempleOS REPL (SerReplExe) is currently running.
        Sends a no-op semicolon and checks for CAFEBABE response.
        Returns True if frozen, False if not.
        """
        try:
            self.s.sendall(b';\n')
            content, _ = self._recv_until_term(timeout=timeout)
            if content is None:
                return False
            self._drain(timeout=2)
            return True
        except Exception:
            return False

    # -------------------------------------------------------------------------
    # Session management
    # -------------------------------------------------------------------------

    def freeze(self):
        """Load SerReplExe via sendkey and wait for REPL to be ready."""
        self._sendkey('#include "C:/Home/SerReplExe.HC"')
        time.sleep(1)
        self._sendkey('Dir;')
        time.sleep(2)
        # Load primitives
        self.send_cmd('#include "C:/Home/SerDir.HC";')
        self.send_cmd('#include "C:/Home/SerFileRead.HC";')
        self.send_cmd('#include "C:/Home/SerFileWrite.HC";')
        self.send_cmd('#include "C:/Home/SerFileExists.HC";')
        self.send_cmd('#include "C:/Home/SerMkDir.HC";')
        self.send_cmd('#include "C:/Home/SerExecI64.HC";')
        self.send_cmd('#include "C:/Home/SerExecStr.HC";')
        self.send_cmd('#include "C:/Home/SerSymExists.HC";')
        self.send_cmd('#include "C:/Home/SerSymList.HC";')
        self.send_cmd('#include "C:/Home/SerMemInfo.HC";')
        self.write_file('C:/Home/SerPrint.HC', _SERPRINT_HC)
        self.send_cmd('#include "C:/Home/SerPrint.HC";')

    def unfreeze(self):
        """Send EXIT to stop the REPL loop."""
        self.s.sendall(b'EXIT\n')
        time.sleep(0.5)

    def save_snapshot(self, name='snap1'):
        """Save a QEMU snapshot."""
        _qmon(f'savevm {name}')

    def load_snapshot(self, name='snap1'):
        """Load a QEMU snapshot."""
        _qmon(f'loadvm {name}')

    def recover(self, snapshot='snap1'):
        """
        Recover from a TempleOS crash or hang.
        1. Load snapshot via QEMU monitor (restores clean VM state)
        2. Reconnect socket (clears any stale buffer)
        3. Re-freeze (reload SerReplExe + all primitives)
        """
        _qmon(f'loadvm {snapshot}')
        time.sleep(3)
        try:
            self.close()
        except Exception:
            pass
        time.sleep(0.5)
        self.connect()
        self.freeze()

    # -------------------------------------------------------------------------
    # Primitives
    # -------------------------------------------------------------------------

    def list_dir(self, pattern):
        """
        List directory entries matching pattern (must include *).
        Returns list of full TempleOS paths, excluding . and ..
        """
        raw = self.send_cmd(f'SerDir("{pattern}");')
        if not raw:
            return []
        lines = raw.decode(errors='replace').strip().splitlines()
        result = []
        for l in lines:
            l = l.replace('\x00', '').strip()
            if l and not l.endswith('/.') and not l.endswith('/..') and l.startswith('C:/'):
                result.append(l)
        return result

    def read_file(self, path, timeout=30):
        """
        Read file contents from TempleOS. Returns bytes.
        Returns None on timeout.
        """
        if path in BANNED_FILES:
            raise ValueError(f"File is banned from transfer: {path}")
        return self.send_cmd(f'SerFileRead("{path}");', timeout=timeout)

    def write_file(self, path, content: bytes):
        """
        Write file to TempleOS.
        content: bytes to write
        """
        self.s.sendall(f'SerFileWrite("{path}");\n'.encode())
        # Wait for ready signal (single \x04)
        buf = b''
        deadline = time.time() + 10
        self.s.settimeout(1.0)
        while time.time() < deadline:
            try:
                chunk = self.s.recv(256)
                if chunk:
                    buf += chunk
                    if b'\x04' in buf:
                        break
            except socket.timeout:
                continue
        # Send file bytes + single EOT
        self.s.sendall(content + b'\x04')
        # Drain OK+TERM
        self._recv_until_term(timeout=10)
        self._drain()

    def file_exists(self, path):
        """Check if a file exists. Returns True/False."""
        raw = self.send_cmd(f'SerFileExists("{path}");')
        if raw is None:
            return False
        return raw.strip() == b'1'

    def mkdir(self, path):
        """Create a directory on TempleOS."""
        self.send_cmd(f'SerMkDir("{path}");')

    def exec(self, code: str):
        """Execute arbitrary HolyC code. Returns OK response."""
        return self.send_cmd(code)

    def exec_i64(self, expr: str):
        """Execute a HolyC expression, return I64 result as int.
        Raises TempleException if TempleOS throws during execution.
        """
        self.exec(f'g_r={expr};')
        raw = self.send_cmd('SerGetI64(g_r);')
        if raw is None:
            return None
        if raw.startswith(b'EXCEPT:'):
            name = raw[7:].decode(errors='replace').strip()
            raise TempleException(name)
        s = raw.decode(errors='replace').strip()
        return int(s) if s else None

    def exec_str(self, code: str):
        """
        Execute HolyC code that populates g_str, return the string.
        Code should call GStrAdd("...") or StrPrint(g_str, fmt, ...).
        Combines reset+code+send into a single REPL command to avoid
        drain desync (GStrAdd/GStrReset don't emit CAFEBABE themselves).
        Note: combined command must fit in SerReplExe's 4096-byte buffer.
        Raises TempleException if TempleOS throws during execution.
        """
        try:
            raw = self.send_cmd(f'GStrReset();{code}SerSendStr();')
        except (ConnectionResetError, OSError):
            raise TempleException('crash')
        # If SerSendStr never ran (exception in user code), SerSendOk fires
        # instead, and send_cmd receives b'OK' as the first CAFEBABE payload.
        if raw == b'OK':
            raise TempleException('exception')
        if raw and raw.startswith(b'EXCEPT:'):
            name = raw[7:].decode(errors='replace').strip()
            raise TempleException(name)
        return raw.decode(errors='replace') if raw else ''

    def symbol_exists(self, name: str) -> bool:
        """Return True if name is defined in the current TempleOS symbol table."""
        return self.exec_str(f'SerSymExists("{name}");') == '1'

    def list_symbols(self, kind='functions', detailed=False) -> list:
        """
        Return symbols from the TempleOS hash table chain.
        kind: 'functions', 'globals', 'classes', 'all'
        detailed=False: returns list of names.
        detailed=True:  returns list of (name, kind) tuples.
        """
        masks = {'functions': 64, 'globals': 8, 'classes': 16, 'all': 131071}
        mask = masks.get(kind, 64)
        raw = self.send_cmd(f'SerSymList({mask});')
        if not raw:
            return []
        rows = [line.split('\t') for line in raw.decode(errors='replace').splitlines() if line]
        if detailed:
            return [(r[0], r[1] if len(r) > 1 else '') for r in rows]
        return [r[0] for r in rows]

    def run_hc(self, code: str, call: str = '',
               path: str = 'C:/AI/code/_tmp.HC'):
        """
        Write HolyC source to TempleOS, compile it via #include, optionally
        call a function and return its exec_str result.
        code: HolyC source as a Python string (use \\n for newlines).
        call: optional HolyC expression to exec_str after loading.
        path: destination path on TempleOS filesystem.
        """
        self.write_file(path, code.encode())
        self.send_cmd(f'#include "{path}";')
        if call:
            return self.exec_str(call)
        return None

    def exec_rows(self, code: str) -> list:
        """Execute HolyC code via exec_str, parse result as TSV rows.
        Each line in the result becomes a list of fields split by tab.
        """
        raw = self.exec_str(code)
        return [line.split('\t') for line in raw.splitlines() if line]

    def exec_kv(self, code: str) -> dict:
        """Execute HolyC code via exec_str, parse result as key\\tvalue pairs."""
        return {r[0]: (r[1] if len(r) > 1 else '') for r in self.exec_rows(code) if r}

    def mem_info(self) -> dict:
        """Return TempleOS memory stats as a dict with integer values."""
        kv = self.exec_kv('SerMemInfo();')
        result = {}
        for k, v in kv.items():
            try:
                result[k] = int(v)
            except ValueError:
                result[k] = v
        return result

    # -------------------------------------------------------------------------
    # Helpers
    # -------------------------------------------------------------------------

    def _sendkey(self, text):
        """Type text into TempleOS via QEMU sendkey (for unfrozen state)."""
        subprocess.run(
            ['/home/zero/temple/sendtext.sh', text],
            check=False
        )


# -------------------------------------------------------------------------
# Module-level helpers
# -------------------------------------------------------------------------

def _qmon(cmd):
    """Send command to QEMU monitor."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(QMON)
        s.sendall((cmd + '\n').encode())
        time.sleep(0.5)
