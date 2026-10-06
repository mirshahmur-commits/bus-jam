# Bus Jam candidate validation

The implemented Flutter candidate passed automated, business and widget acceptance
checks. Native iOS and provider checks remain unexecuted and block store distribution.

## Exact validated candidate

- Version: `1.0.0+1`; Flutter 3.47.6 / Dart 3.13.5.
- Commit: `541997f9e74f265a6b67bda2c790f91c408f4407`.
- App/native/dependency source SHA-256:
  `7efd3401c6b0e64c7a5b1a8d2a774f5b51bb323a90eb4da0091616921132a769`.
- Execution: Ubuntu 24.04.5, GitHub Actions, 6 October 2026.
- [Successful workflow run](https://github.com/mirshahmur-commits/bus-jam/actions/runs/37469811952).
- Machine-readable outcomes: [github-validation.json](evidence/github-validation.json).
  Documentation/evidence-only commits do not change the app source identity.

| Executed check | Actual result |
| --- | --- |
| Formatting | Passed; 22 Dart files, zero changes |
| Static analysis | Passed; no issues |
| Game rules | 15 tests passed |
| Controller/business behavior | 27 tests passed |
| Persistence/analytics/ad failure handling | 4 tests passed |
| Widget acceptance journeys/layout variants | 11 tests passed |
| Rendered screenshot scenario | 1 test passed |
| Total Flutter tests | **58 passed, zero failed or skipped** |
| Procedural levels | 10,000 witnesses solved; 149,839 legal moves |
| Independent level solver | 300 generated levels solved |
| Release web compilation | Passed, including Wasm dry run; web build completed in 37 seconds |

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

The committed screenshots in `evidence/screens/` were captured during the earlier
54-test local run and visually reviewed then. The final CI reran the rendered
screenshot scenario successfully; its generated PNG files were not exported.
Web compilation is confirmed; interactive browser play has not been executed.
These checks do not substitute for iPhone device acceptance.

Fixed during implementation: invalid gradient stops, narrow-screen overflow,
tutorial navigation context, lifecycle test timing, audio-plugin initialization
during widget tests, missing test font/icon resources, boarding animation positions,
and final formatting/import issues. The final workflow passed after corrections.

## Required native checks

| Check | Status | Evidence still required |
| --- | --- | --- |
| iOS compilation and signed candidate | Not run | Codemagic build for exact candidate |
| iPhone simulator/device UAT | Not run | Native journeys/screenshots; audio, haptics, lifecycle and performance |
| StoreKit sandbox | Not run | Verified purchase, cancel, pending, restore and revocation |
| AdMob test device and consent | Not run | Earned/closed/failed/offline ad flows and UMP choices |
| Privacy and store metadata | Not run | Owner's privacy URL and App Store declarations |
| Android billing/release | Not run | Separate later Android delivery |

`release-readiness.json` records Passed only for executed automated/business checks.
The release gate correctly rejects distribution until the remaining evidence is
available. Mocked purchases and ads do not establish native provider correctness.
