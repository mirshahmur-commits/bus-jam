# Bus Jam candidate validation

This report distinguishes executed local checks from native release checks.
The candidate is not cleared for App Store distribution.

## Executed before final candidate synchronization

- Flutter 3.47.6 / Dart 3.13.5 on Linux: static analysis passed.
- 54 Flutter tests passed: rules, controller business outcomes, player journeys,
  responsive layouts, and rendered screenshot scenarios.
- 10,000 generated levels solved with their known witnesses (149,839 moves).
  The independent solver also solved 300 generated levels.
- Release web compilation passed.
- UI journeys UAT-01 through UAT-07 executed with actual widget taps. Responsive
  layouts covered 320×568, 375×667, 390×844, 430×932, and 768×1024.
- Screenshots in `evidence/screens/` show the home, game, win, fail, and settings.

Four additional persistence/analytics/ad-exception tests and revenue callbacks
were added afterward. These changes require the final GitHub Actions run;
the earlier 54 results do not validate these additions.

## Defects found and corrected during local acceptance

Fixed invalid gradient stops, narrow-screen overflow, a tutorial navigation
context error, lifecycle test timing, plugin audio initialization during widget
tests, and missing test-loaded font/icon resources. The 54-test suite passed
after those corrections and the screenshots were regenerated.

## Required native checks

| Check | Status | Evidence still required |
| --- | --- | --- |
| iOS compilation and signed candidate | Not run | Codemagic build for exact source identity |
| iPhone simulator/device UAT | Not run | Native journeys and screenshots; audio, haptics, lifecycle and performance |
| StoreKit sandbox | Not run | Verified purchase, cancel, pending, restore and revocation |
| AdMob test device and consent | Not run | Earned/closed/failed/offline ad flows and UMP choices |
| Privacy and store metadata | Not run | Owner's privacy URL and App Store declarations |
| Android billing/release | Not run | Separate later Android delivery |

`release-readiness.json` is the machine-readable distribution gate. Mocked
purchase/ad business tests do not establish native provider correctness.
