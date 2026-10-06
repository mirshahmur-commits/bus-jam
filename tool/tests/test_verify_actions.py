import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_actions import GateError, verified_run

COMMIT = "a" * 40


class ActionsGateTests(unittest.TestCase):
    def setUp(self):
        self.run = {
            "id": 10, "head_sha": COMMIT, "head_branch": "main", "event": "push",
            "path": ".github/workflows/flutter-ci.yml", "status": "completed",
            "conclusion": "success", "html_url": "https://github.com/example/run/10",
        }
        self.runs = [self.run]
        self.jobs = [
            {"name": name, "status": "completed", "conclusion": "success"}
            for name in ["quality", "iOS simulator acceptance"]
        ]

    def read(self, path):
        return {"jobs": self.jobs} if "/jobs?" in path else {"workflow_runs": self.runs}

    def test_accepts_success_for_exact_main_commit(self):
        self.assertEqual(verified_run(COMMIT, self.read)["run_id"], 10)

    def test_rejects_other_commit(self):
        self.run["head_sha"] = "b" * 40
        with self.assertRaises(GateError):
            verified_run(COMMIT, self.read)

    def test_rejects_pull_request_run(self):
        self.run["event"] = "pull_request"
        with self.assertRaises(GateError):
            verified_run(COMMIT, self.read)

    def test_rejects_missing_native_job(self):
        self.jobs = self.jobs[:1]
        with self.assertRaises(GateError):
            verified_run(COMMIT, self.read)

    def test_rejects_skipped_native_job(self):
        self.jobs[1]["conclusion"] = "skipped"
        with self.assertRaises(GateError):
            verified_run(COMMIT, self.read)

    def test_latest_failed_attempt_cannot_reuse_prior_success(self):
        self.runs.append({**self.run, "id": 11, "conclusion": "failure"})
        with self.assertRaises(GateError):
            verified_run(COMMIT, self.read)

    def test_rejects_pending_run(self):
        self.run["status"] = "in_progress"
        self.run["conclusion"] = None
        with self.assertRaises(GateError):
            verified_run(COMMIT, self.read)

    def test_rejects_invalid_commit(self):
        with self.assertRaises(GateError):
            verified_run("main", self.read)


if __name__ == "__main__":
    unittest.main()
