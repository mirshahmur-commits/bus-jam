"""Exercise VM readiness against real local HTTP responses."""

import contextlib
import importlib.util
import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("wait_vm_service", ROOT / "tool/wait_vm_service.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


@contextlib.contextmanager
def service(responses):
    requests = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            requests.append(self.path)
            value = responses[min(len(requests) - 1, len(responses) - 1)]
            body = value if isinstance(value, bytes) else json.dumps(value).encode()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    server = HTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(
        target=lambda: server.serve_forever(poll_interval=0.01), daemon=True
    )
    thread.start()
    try:
        yield server.server_port, requests
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=1)


def vm(pid, isolates=None):
    return {
        "result": {
            "type": "VM",
            "pid": pid,
            "isolates": isolates if isolates is not None else [{"id": "isolates/1"}],
        }
    }


class SimulatorVMTests(unittest.TestCase):
    def test_accepts_owned_running_vm(self):
        with service([vm(321)]) as (port, requests):
            self.assertEqual(MODULE.wait_for_vm(port, 321, seconds=1), f"http://127.0.0.1:{port}/")
            self.assertEqual(requests, ["/getVM"])

    def test_rejects_another_process_on_the_port(self):
        with service([vm(999)]) as (port, _):
            with self.assertRaises(TimeoutError):
                MODULE.wait_for_vm(port, 321, seconds=0.05)

    def test_waits_for_main_isolate_and_recovers_from_incomplete_response(self):
        with service([b"not JSON", vm(321, []), vm(321)]) as (port, requests):
            self.assertEqual(MODULE.wait_for_vm(port, 321, seconds=2), f"http://127.0.0.1:{port}/")
            self.assertEqual(len(requests), 3)

    def test_rejects_rpc_error_response(self):
        with service([{"error": {"message": "VM unavailable"}}]) as (port, _):
            with self.assertRaises(TimeoutError):
                MODULE.wait_for_vm(port, 321, seconds=0.05)

    def test_requires_successful_launch_identity(self):
        self.assertEqual(MODULE.launched_pid("com.systemcraft.busJam: 321\n"), 321)
        for log in ["launch failed", "other.bundle: 321", "com.systemcraft.busJam: 1\ncom.systemcraft.busJam: 2\n"]:
            with self.subTest(log=log), self.assertRaises(ValueError):
                MODULE.launched_pid(log)


if __name__ == "__main__":
    unittest.main()
