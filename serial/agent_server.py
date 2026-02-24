#!/usr/bin/env python3
"""
agent_server.py — HTTP command/result server for the TempleOS agent loop.

Endpoints:
  GET  /cmd    → return next queued command as plain text (empty if none)
  POST /result → store body as latest result, echo back "ECHO:<body>"

Usage:
  python3 serial/agent_server.py [port]   (default: 8081)

From another terminal / Python session:
  from serial.agent_server import push_cmd, get_result
  push_cmd('Print("hello\\n");')
  print(get_result())
"""

import sys, os, queue, threading, time
from http.server import HTTPServer, BaseHTTPRequestHandler

_cmd_queue    = queue.Queue()
_result_queue = queue.Queue()   # one entry per POST /result; no race condition


class _Handler(BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path == '/cmd':
            try:
                cmd = _cmd_queue.get_nowait()
            except queue.Empty:
                cmd = ''
            body = cmd.encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.send_header('Content-Length', '0')
            self.end_headers()

    def do_POST(self):
        if self.path == '/result':
            length = int(self.headers.get('Content-Length', 0))
            body   = self.rfile.read(length)
            _result_queue.put(body)   # enqueue; get_result() dequeues in order
            echo = b'ECHO:' + body
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.send_header('Content-Length', str(len(echo)))
            self.end_headers()
            self.wfile.write(echo)
        else:
            self.send_response(404)
            self.send_header('Content-Length', '0')
            self.end_headers()

    def log_message(self, fmt, *args):
        # Print one-liner to stdout so the user can see activity
        sys.stdout.write('[agent] %s\n' % (fmt % args))
        sys.stdout.flush()


# ── Public API ────────────────────────────────────────────────────────────────

def push_cmd(cmd: str):
    """Enqueue a HolyC snippet for TempleOS to fetch via GET /cmd."""
    _cmd_queue.put(cmd)


def get_result(timeout: float = 30) -> bytes | None:
    """Block until TempleOS POSTs a result, or timeout. Returns raw bytes."""
    try:
        return _result_queue.get(timeout=timeout)
    except queue.Empty:
        return None


def start_background(port: int = 8081) -> HTTPServer:
    """Start the server in a daemon thread; return the HTTPServer instance."""
    server = HTTPServer(('0.0.0.0', port), _Handler)
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    return server


# ── CLI entry point ───────────────────────────────────────────────────────────

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8081
    print(f'Agent server listening on :{port}')
    print('  GET  /cmd    → serve next queued HolyC command (empty if none)')
    print('  POST /result → store result body, echo back ECHO:<body>')
    server = HTTPServer(('0.0.0.0', port), _Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nShutting down.')
