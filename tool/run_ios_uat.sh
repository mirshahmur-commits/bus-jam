#!/usr/bin/env bash
set -euo pipefail
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true
mkdir -p test-results/ios-screens
python3 tool/source_identity.py > test-results/ios-source-identity.json
udid=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; j=json.load(sys.stdin); d=[d for k,v in j["devices"].items() if "iOS" in k for d in v if "iPhone" in d["name"]]; print(d[0]["udid"] if d else "")')
if [[ -z "$udid" ]]; then printf 'No available iPhone simulator\n' >&2; exit 1; fi
xcrun simctl boot "$udid" || xcrun simctl list devices booted -j | python3 -c 'import json,sys; j=json.load(sys.stdin); target=sys.argv[1]; sys.exit(0 if any(d["udid"]==target for v in j["devices"].values() for d in v) else 1)' "$udid"
xcrun simctl bootstatus "$udid" -b
xcrun simctl list devices available -j > test-results/ios-environment.json
flutter drive --driver=test_driver/integration_driver.dart --target=integration_test/app_test.dart -d "$udid" 2>&1 | tee test-results/ios-drive.log
python3 - <<'PY'
import json
from pathlib import Path
report=json.loads(Path('test-results/ios-uat.json').read_text())
assert report.get('journey') == 'Passed', 'Native player journey did not pass'
screens=list(Path('test-results/ios-screens').glob('*.png'))
assert len(screens) == 5 and all(p.stat().st_size > 0 for p in screens), 'Expected five native screenshots'
print('Native journey Passed with five screenshots.')
PY
