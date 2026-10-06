#!/usr/bin/env python3
"""Read-only exact-commit GitHub CI gate before a Codemagic TestFlight build."""
import json
import os
import re
import subprocess
import sys
from urllib.parse import urlencode
from urllib.request import Request, urlopen

REPOSITORY = "mirshahmur-commits/bus-jam"
REQUIRED_JOBS = {"quality", "iOS simulator acceptance"}


class GateError(RuntimeError):
    pass


def verified_run(commit, get_json):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise GateError("A full commit SHA is required")
    query = urlencode({"head_sha": commit, "event": "push", "branch": "main", "per_page": 20})
    payload = get_json(f"/repos/{REPOSITORY}/actions/workflows/flutter-ci.yml/runs?{query}")
    runs = [
        run for run in payload.get("workflow_runs", [])
        if run.get("head_sha") == commit and run.get("head_branch") == "main"
        and run.get("event") == "push"
        and run.get("path") == ".github/workflows/flutter-ci.yml"
    ]
    if not runs:
        raise GateError("No Actions run exists for this exact main commit")
    run = max(runs, key=lambda item: (item["id"], item.get("run_attempt", 1)))
    if run.get("status") != "completed" or run.get("conclusion") != "success":
        raise GateError("Latest Actions run is not successfully completed")
    jobs = get_json(f"/repos/{REPOSITORY}/actions/runs/{run['id']}/jobs?filter=latest&per_page=100")
    successful = {
        job["name"] for job in jobs.get("jobs", [])
        if job.get("status") == "completed" and job.get("conclusion") == "success"
    }
    missing = REQUIRED_JOBS - successful
    if missing:
        raise GateError("Required successful jobs missing: " + ", ".join(sorted(missing)))
    return {"commit": commit, "run_id": run["id"], "url": run["html_url"], "status": "Passed"}


def github_json(path):
    headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2026-03-10"}
    token = os.environ.get("GITHUB_READ_TOKEN")
    if token:
        headers["Authorization"] = "Bearer " + token
    request = Request("https://api.github.com" + path, headers=headers)
    with urlopen(request, timeout=20) as response:
        return json.load(response)


def main():
    commit = os.environ.get("CM_COMMIT")
    if not commit:
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    try:
        result = verified_run(commit, github_json)
    except Exception as error:
        # Never print headers/tokens. Network/API failures keep the gate closed.
        print("TestFlight build blocked: " + str(error), file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
