# Bus Jam candidate validation

The implemented Flutter candidate passed automated, business and widget acceptance
checks and native iPhone simulator acceptance in GitHub Actions. Codemagic only
builds and uploads TestFlight. Provider checks remain separate from simulator tests.

## Exact validated candidate

- Version: `1.0.0+1`; Flutter 3.47.6 / Dart 3.13.5.
- Commit: `9b1e4de1467dc6a0b5e85391b740f00a8f3472e8`.
- App/native/dependency source SHA-256:
  `3ce99297f8f09d622128be8a7ff6b87afa739a80c85989566c3459b181e257c1`.
- Execution: Ubuntu 24.04.5 and macOS 15.7.9 ARM64, Actions, 6 October 2026.
- [Actions run](https://github.com/mirshahmur-commits/bus-jam/actions/runs/37481404577),
  Linux job `112330164519` and native job `112331418486` both passed.
- Machine-readable outcomes: [github-validation.json](evidence/github-validation.json).
  Documentation/evidence-only commits do not change the app source identity.

| Executed check | Actual result |
| --- | --- |
| Formatting | Passed; 22 Dart files, zero changes |
| Static analysis | Passed; no issues |
| Game rules | 15 tests passed |
| Controller/business behavior | 27 tests passed |
| Persistence/analytics/ad failure handling | 4 tests passed |
| Widget acceptance journeys/layout variants | 12 tests passed |
| Rendered screenshot scenario | 1 test passed |
| Total Flutter tests | **59 passed, zero failed or skipped** |
| Exact-commit TestFlight CI gate | 8 Python tests passed |
| Native iPhone player journey | 1 journey passed; five screenshots captured |
| Normal iOS simulator app compilation | Passed |
| Procedural levels | 10,000 witnesses solved; 149,839 legal moves |
| Independent level solver | 300 generated levels solved |
| Release web compilation | Passed, including Wasm dry run |

The 46 rule/controller/platform tests cover 41 named business rules and expanded
purchase/ad outcomes: legal/illegal moves, FIFO matching, conservation, blocked
parking, win, deterministic saves/generation, exact restore, corrupt saves, daily
date/streak/reward behavior, locked routes, replay protection, assist charging,
duplicate requests, ad cadence, cancellation/pending/restore/revocation contracts,
serialized writes and provider/save failures. Provider contracts use test doubles.

## Acceptance execution and its limits

UAT-01 through UAT-07 in [UAT.md](UAT.md) ran with actual Flutter widget taps:
onboarding → win → next; jam → continue → win; hint/undo/restart/settings;
daily/campaign/map locks; unavailable video; lifecycle save/relaunch; responsive
layouts at 320×568, 375×667, 390×844, 430×932 and 768×1024.
Expected state, coins, visible result and absence of layout/framework exceptions
were asserted. Repeat reward checks (UAT-08) passed in business tests.

UAT-09 also passed: settings remain usable while the store price is pending, and
the returned price updates within the already open sheet.

The committed screenshots in `evidence/screens/` were captured during the earlier
54-test local run and visually reviewed then. The final CI reran the rendered
screenshot scenario successfully; its generated PNG files were not exported.
Web compilation is confirmed; interactive browser play has not been executed.
The native Actions run additionally tested first launch/tutorial, win/reward/next,
paid hint, persisted save/restore, jam/continue/win and reduced-motion settings on
an iPhone 16 Pro simulator. The actual five PNGs are committed in `evidence/ios/`;
[ios-validation.json](evidence/ios-validation.json) records their hashes and results.
Native execution used macOS 15.7.9 ARM64 and Xcode 16.4. Flutter's standard CocoaPods
configuration adds two include lines to the iOS xcconfig files; the native prebuild
hash is recorded separately and was reproduced exactly from those two additions.
Simulator checks do not substitute for physical iPhone/provider acceptance.

Fixed during implementation: invalid gradient stops, narrow-screen overflow,
tutorial navigation context, lifecycle test timing, audio-plugin initialization
during widget tests, missing test font/icon resources, boarding animation positions,
and final formatting/import issues. Native Actions then revealed a plugin resolver
conflict and settings waiting for StoreKit pricing. The pinned plugins now use one
native resolver, and settings open immediately with asynchronous pricing; a
regression test covers the delay. The full workflow passed after corrections.

## Required native checks

| Check | Status | Evidence still required |
| --- | --- | --- |
| iOS simulator compilation | Passed | Actions job `112331418486`, native evidence JSON |
| iPhone simulator UAT | Passed | Player journey and five committed native screenshots |
| Signed iPhone candidate/device acceptance | Not run | Codemagic TestFlight build, audio/haptics/lifecycle/performance |
| StoreKit sandbox | Not run | Verified purchase, cancel, pending, restore and revocation |
| AdMob test device and consent | Not run | Earned/closed/failed/offline ad flows and UMP choices |
| Privacy and store metadata | Not run | Owner's privacy URL and App Store declarations |
| Android billing/release | Not run | Separate later Android delivery |

`release-readiness.json` records Passed for executed automated, business and native
simulator checks. Signed TestFlight/device/provider checks remain Not run.
The full release gate rejects App Store distribution until remaining evidence is
available. Internal TestFlight uses successful exact-commit Actions as its build
gate so the signed candidate can be used for subsequent device/provider checks.
Mocked purchases and ads do not establish native provider correctness.
