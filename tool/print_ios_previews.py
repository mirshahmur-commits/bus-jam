#!/usr/bin/env python3
"""Bounded native screen previews for visual QA through CI logs."""
import base64
import json
import subprocess
from pathlib import Path

root = Path("test-results")
for name, prefix in [
    ("ios-source-identity.json", "IOS_IDENTITY "),
    ("ios-uat.json", "IOS_REPORT "),
]:
    report = root / name
    if report.exists():
        print(prefix + json.dumps(json.loads(report.read_text())))

screens = sorted((root / "ios-screens").glob("*.png"))
if len(screens) > 7:
    raise SystemExit("Unexpected native screen count")
previews = root / "ios-previews"
previews.mkdir(parents=True, exist_ok=True)
encoded_size = 0
for screen in screens:
    preview = previews / screen.name
    subprocess.run(
        ["sips", "--resampleWidth", "480", str(screen), "--out", str(preview)],
        check=True,
        stdout=subprocess.DEVNULL,
        timeout=30,
    )
    data = base64.b64encode(preview.read_bytes()).decode("ascii")
    encoded_size += len(data)
    if encoded_size > 2 * 1024 * 1024:
        raise SystemExit("Native preview log exceeds 2 MiB")
    print("IOS_PREVIEW " + json.dumps({"name": screen.name, "base64": data}))
