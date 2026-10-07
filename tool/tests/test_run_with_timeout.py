import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

RUNNER = Path(__file__).resolve().parents[1] / "run_with_timeout.py"


class CommandDeadlineTests(unittest.TestCase):
    def command(self, seconds, code):
        return [sys.executable, str(RUNNER), str(seconds), sys.executable, "-u", "-c", code]

    def test_keeps_stdout_clean_for_simulator_id_capture(self):
        result = subprocess.run(self.command(5, "print('simulator-id')"), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "simulator-id\n")

    def test_preserves_failure_code(self):
        result = subprocess.run(self.command(5, "raise SystemExit(37)"), capture_output=True)
        self.assertEqual(result.returncode, 37)

    def test_timeout_kills_children_that_ignore_term(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder) / "survived"
            child = f"import signal,time,pathlib; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(2); pathlib.Path({str(marker)!r}).touch()"
            parent = f"import subprocess,sys,time,signal; signal.signal(signal.SIGTERM,signal.SIG_IGN); subprocess.Popen([sys.executable,'-c',{child!r}]); time.sleep(30)"
            result = subprocess.run(self.command(0.5, parent), capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 124)
            time.sleep(1)
            self.assertFalse(marker.exists(), "A timed-out child must not keep running")

    def test_cancellation_stops_command_group(self):
        process = subprocess.Popen(self.command(30, "import time; print('ready',flush=True); time.sleep(30)"), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertEqual(process.stdout.readline().strip(), "ready")
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=5)
            self.assertEqual(process.returncode, 143)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL) if os.getpgid(process.pid) == process.pid else process.kill()


if __name__ == "__main__":
    unittest.main()
