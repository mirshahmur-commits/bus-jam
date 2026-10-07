#!/usr/bin/env python3
"""Bound a CI command and its children, preserving output and failure status."""
import argparse
import os
import signal
import subprocess
import sys
import time


def stop_group(process):
    def send(sig):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            pass
        except PermissionError:
            # macOS may refuse signals to a protected helper in xcrun's group.
            # Still stop our own command; never replace timeout/cancellation
            # with an unrelated cleanup traceback.
            if process.poll() is None:
                try:
                    process.send_signal(sig)
                except (ProcessLookupError, PermissionError):
                    pass

    send(signal.SIGTERM)
    # Children can ignore TERM even if their parent has already exited.
    time.sleep(1)
    send(signal.SIGKILL)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        print("CI cleanup could not reap a system-managed command", file=sys.stderr, flush=True)


def run(seconds, command):
    # Include the tool's operation, without logging values or command secrets.
    operation = " ".join(command[:3]) if command[0] == "xcrun" else command[0]
    print(f"CI stage: {operation} (limit {seconds:g}s)", file=sys.stderr, flush=True)
    process = subprocess.Popen(command, start_new_session=True)
    cancelled = []
    previous = {}
    for sig in (signal.SIGTERM, signal.SIGINT):
        previous[sig] = signal.signal(sig, lambda number, frame: cancelled.append(number))
    started = time.monotonic()
    try:
        while True:
            if cancelled:
                stop_group(process)
                return 128 + cancelled[0]
            remaining = seconds - (time.monotonic() - started)
            if remaining <= 0:
                print(f"CI stage timed out: {command[0]}", file=sys.stderr, flush=True)
                stop_group(process)
                return 124
            try:
                code = process.wait(timeout=min(1, remaining))
                return code if code >= 0 else 128 - code
            except subprocess.TimeoutExpired:
                pass
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("seconds", type=float)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.seconds <= 0 or not args.command:
        parser.error("provide a positive time limit and a command")
    return run(args.seconds, args.command)


if __name__ == "__main__":
    sys.exit(main())

