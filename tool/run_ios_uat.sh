#!/usr/bin/env bash
set -euo pipefail
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true
mkdir -p test-results/ios-screens
rm -f test-results/ios-uat.json test-results/ios-screens/*.png
python3 tool/source_identity.py > test-results/ios-source-identity.json
bounded() { python3 -u tool/run_with_timeout.py "$@"; }

# Compile before booting: CoreSimulator and Xcode should not compete for memory.
bounded 900 flutter build ios --simulator --debug --no-pub \
  --target=integration_test/app_test.dart 2>&1 | tee test-results/ios-build.log

# Match the runtime to the selected Xcode SDK and create an isolated device.
# Hosted images also contain newer runtimes and pre-created devices.
sdk=$(bounded 30 xcrun --sdk iphonesimulator --show-sdk-version)
bounded 60 xcrun simctl list runtimes -j > test-results/ios-runtimes.json
runtime=$(python3 - "$sdk" <<'PY'
import json,sys
from pathlib import Path
items=json.loads(Path('test-results/ios-runtimes.json').read_text())['runtimes']
matches=[r for r in items if r.get('isAvailable') and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-') and r['version']==sys.argv[1]]
if not matches: raise SystemExit('No installed iOS runtime matching the selected Xcode SDK '+sys.argv[1])
print(matches[0]['identifier'])
PY
)
udid=$(bounded 60 xcrun simctl create "BusSurge-UAT-${GITHUB_RUN_ID:-local}" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro "$runtime")
cleanup() {
  status=$?
  trap - EXIT
  bounded 30 xcrun simctl list devices -j > test-results/ios-environment.json || true
  bounded 30 xcrun simctl shutdown "$udid" || true
  bounded 30 xcrun simctl delete "$udid" || true
  exit "$status"
}
trap cleanup EXIT
printf 'Native UAT device: %s; runtime: %s; SDK: %s\n' "$udid" "$runtime" "$sdk"
bounded 60 xcrun simctl boot "$udid"
bounded 180 xcrun simctl bootstatus "$udid" -b
# Confirm the simulator can answer app-management requests before Flutter drive.
bounded 60 xcrun simctl listapps "$udid" > test-results/ios-apps.json
bounded 600 flutter drive --verbose --no-pub \
  --driver=test_driver/integration_driver.dart --target=integration_test/app_test.dart \
  --use-application-binary=build/ios/iphonesimulator/Runner.app \
  -d "$udid" 2>&1 | tee test-results/ios-drive.log
python3 - <<'PY'
import json
from pathlib import Path
report=json.loads(Path('test-results/ios-uat.json').read_text())
assert report.get('journey') == 'Passed', 'Native player journey did not pass'
screens=list(Path('test-results/ios-screens').glob('*.png'))
assert len(screens) == 5 and all(p.stat().st_size > 0 for p in screens), 'Expected five native screenshots'
print('Native journey Passed with five screenshots.')
PY

