#!/usr/bin/env python3
"""Wait for the owned simulator app's VM directly, without startup-log discovery."""

import argparse
import json
import re
import sys
import time
from pathlib import Path
from urllib.request import ProxyHandler, build_opener


def launched_pid(log):
    matches = re.findall(r"^com\.systemcraft\.busJam:\s+(\d+)\s*$", log, re.MULTILINE)
    if len(matches) != 1:
        raise ValueError("Expected one successful Bus Surge simulator launch with a PID")
    return int(matches[0])


def wait_for_vm(port, expected_pid, seconds=120):
    if not 1 <= port <= 65535:
        raise ValueError("Invalid local VM port")
    uri = f"http://127.0.0.1:{port}/"
    opener = build_opener(ProxyHandler({}))
    deadline = time.monotonic() + seconds
    print(f"Waiting for simulator VM: port={port}, pid={expected_pid}", file=sys.stderr)
    while time.monotonic() < deadline:
        try:
            remaining = deadline - time.monotonic()
            with opener.open(uri + "getVM", timeout=max(0.01, min(2, remaining))) as response:
                payload = json.load(response)
            vm = payload.get("result", {})
            if (
                vm.get("type") == "VM"
                and vm.get("pid") == expected_pid
                and isinstance(vm.get("isolates"), list)
                and vm["isolates"]
            ):
                return uri
        except (OSError, ValueError, AttributeError):
            pass
        time.sleep(min(0.25, max(0, deadline - time.monotonic())))
    raise TimeoutError(f"Simulator VM for pid {expected_pid} did not become ready")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", type=int)
    parser.add_argument("launch_log", type=Path)
    args = parser.parse_args()
    try:
        print(wait_for_vm(args.port, launched_pid(args.launch_log.read_text())))
    except (OSError, ValueError, TimeoutError) as error:
        print(str(error), file=sys.stderr)
        return 124 if isinstance(error, TimeoutError) else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
