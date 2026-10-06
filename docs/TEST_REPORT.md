# Bus Jam — approved urban artwork validation

The complete urban artwork candidate passed automated, business, widget/layout
and native iPhone simulator acceptance in GitHub Actions on 6 October 2026.
Codemagic signs/builds/uploads internal TestFlight only after successful Actions
for the exact main commit. Simulator success does not replace signed device or
real StoreKit/AdMob acceptance.

## Exact validated candidate

- Version `1.0.0+1`; Flutter 3.47.6 / Dart 3.13.5.
- App candidate commit: `97995bcf2a0b6e2ae2cf8780ff375cdc192198a2`.
- Actions PR execution commit: `59da2e3e147a0d0577b6443cc1caff52768d86bb`.
- Runtime source SHA-256 (105 committed files):
  `90e8863994843d1a1c5dc07ec7bc97b4a1af82c29c01e2e7b032ae142ece0365`.
- [Successful Actions run](https://github.com/mirshahmur-commits/bus-jam/actions/runs/37495390513).
- Linux job `112378486432`, native job `112379672444` both passed.
- Machine-readable [Linux/business results](evidence/github-validation.json)
  and [native results](evidence/ios-validation.json).

Documentation and screenshot evidence commits preserve this runtime identity.
Main push checks still repeat for the exact merge commit before TestFlight.

## Executed checks

| Check | Observed result |
| --- | --- |
| Formatting | 24 Dart files, no changes |
| Static analysis | No issues |
| Game rules | 15 passed |
| Controller/business behavior | 27 passed |
| Persistence/analytics/provider failure handling | 4 passed |
| Widget journeys and five screen sizes | 12 passed |
| Five-screen screenshot scenario | 1 passed |
| Actual bundled urban art: visible PNGs, alpha, proportions | 2 passed |
| Total Flutter tests | 61 passed; zero failed or skipped |
| Exact-commit TestFlight gate tests | 8 passed |
| Deterministic levels | 10,000 validated |
| Witness moves / independent solver levels | 149,839 / 300 |
| Portable release build | JavaScript web build passed; Wasm dry run succeeded |
| Native iPhone player journey | Passed with five screenshots |
| Normal iOS debug simulator compilation | Passed |

The native journey exercises first launch/onboarding, passenger matching, route
victory, next route, paid hint, mid-level save/relaunch, a real blocked parking
fixture, paid continuation to a fourth slot, victory and usable settings.

## Artwork and visual acceptance

The owner-approved bus/person sheet supplies the actual sprites. City, wordmark,
app/launch icons and result art match its adult urban game style. Source sprites
and the [prompt/inventory document](ART_DIRECTION.md) are committed. Assets are
decoded before first frame and reused by the home scene and animated board.
Readable matching badges, live seat dots and hint outlines remain geometric.

The five native captures were inspected: the artwork renders on home/gameplay,
win/fail panels show the new illustrations, and settings controls remain usable.
Exact native PNGs are preserved in [evidence/ios](evidence/ios/); README previews
use the same bytes. Native evidence totaled 4,759,447 bytes, below the 16 MiB cap.
ZIP artifact `11427782746` SHA-256:
`00bc761f081260ee0aff3a7992ab3b9b11d3040b27746cbcc1f3a05dd10d47e3`.

Native platform: macOS 15.7.9 ARM64, Xcode 16.4 (16F6), iPhone 16 Pro simulator.
Native prebuild source identity:
`95ce6851db0626a08ce109d9400c8aa62a68a6a6b2866f2e4e49b6e7f8b545ee`.
This differs solely because Flutter pub get adds the standard CocoaPods include
line to Debug.xcconfig and Release.xcconfig. Reproducing those two additions gives
the exact observed native hash.

## Remaining platform acceptance

Signed TestFlight compilation/upload, physical-device checks, StoreKit sandbox,
real ad/consent verification and privacy/store metadata remain unexecuted. The
App Store release gate remains closed. Internal TestFlight supports subsequent
provider acceptance and is gated independently on successful exact-main Actions.
