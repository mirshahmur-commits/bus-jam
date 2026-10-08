#!/usr/bin/env bash
set -euo pipefail
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true
mkdir -p test-results
flutter pub get --enforce-lockfile
dart format lib test integration_test tool test_driver
flutter analyze --fatal-infos
flutter test --coverage --machine > test-results/flutter.json
dart run tool/check_core.dart 10000
python3 tool/source_identity.py > test-results/source-identity.json
git diff --exit-code -- lib test integration_test tool test_driver
