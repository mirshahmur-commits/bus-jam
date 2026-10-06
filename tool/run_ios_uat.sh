#!/usr/bin/env bash
set -euo pipefail
mkdir -p test-results/ios-screens
python3 tool/source_identity.py > test-results/ios-source-identity.json
udid=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; j=json.load(sys.stdin); d=[d for k,v in j["devices"].items() if "iOS" in k for d in v if "iPhone" in d["name"]]; print(d[0]["udid"] if d else "")')
if [[ -z "$udid" ]]; then printf 'No available iPhone simulator\n' >&2; exit 1; fi
xcrun simctl boot "$udid" || xcrun simctl list devices booted | rg -q "$udid"
xcrun simctl bootstatus "$udid" -b
flutter drive --driver=test_driver/integration_driver.dart --target=integration_test/app_test.dart -d "$udid"
xcrun simctl list devices available -j > test-results/ios-environment.json
