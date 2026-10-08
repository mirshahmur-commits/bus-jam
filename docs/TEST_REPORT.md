# Bus Surge 1.1 validation

Version `1.1.0+2` passed automated checks, business rules and native iPhone
simulator acceptance on 8 October 2026. Seven actual native captures were
visually inspected and their JPEG previews are preserved in [redesign evidence](evidence/redesign/).

## Exact tested source

- Candidate: `ca3000c7a595d29e984627318073762dabdd1b01`.
- PR checkout: `59ef91d05f32aa45572af00819656b49ece01483`.
- Committed runtime identity (111 files): `de55934591b9b2024b0a08fa75dbdb9c8d11b11f463687f8178b5965bcc01e32`.
- [Successful Actions run](https://github.com/mirshahmur-commits/bus-jam/actions/runs/37775634596); Linux job `113305621565`
  and native job `113306505680` both completed successfully.
- [Linux results](evidence/redesign/github-validation.json) and
  [native results](evidence/redesign/ios-validation.json) record the exact evidence.

Documentation and screenshot preservation do not change the runtime identity.
Both checks repeat on the exact merged main commit before the Codemagic gate accepts it.

## Executed checks

| Check | Observed result |
| --- | --- |
| Formatting and strict analysis | 31 Dart files, zero formatting changes; no issues |
| Game rules | 15 passed |
| Controller/business behavior | 27 passed |
| Persistence/provider behavior | 4 passed |
| Existing widgets/layouts | 12 passed |
| Screenshot scenario | 1 passed |
| Bundled artwork | 2 passed |
| New puzzle/scoring/collection rules | 14 passed |
| New input/garage widgets | 5 passed |
| Total Flutter tests | 80 passed; zero failed or skipped |
| Python signing/CI infrastructure tests | 21 passed |
| Generated levels | 10,000 validated; 78,412 executed witness moves |
| Independent solver checks | 300 levels |
| Web release compilation | Passed |
| Native iPhone acceptance | Passed |
| Normal iOS simulator compilation | Passed |
| Native visual inspection | Seven screenshots inspected |

Native acceptance includes rapid taps 40 ms apart during motion, first-launch
onboarding, victory, hint, exact save/relaunch, blocked-terminal recovery, settings,
then earning enough coins through route play to buy Metro Line, relaunching and
retaining equipment and 24 stars. Migration tests preserve generator-1 boards
and exclude legacy daily puzzles from generator-2 competition.

Inspected captures show the new home, playable board, score/stars result,
terminal-full recovery, settings, equipped Metro Line and route map. Full native
PNGs remain in the one-day Actions artifact `11550346577` (4658748 compressed bytes),
with digest `sha256:62a2b288c206b24b1607adfc301e8973d21fe8f028fbd96f8a114e4a249c4732`; permanent previews are 480-pixel JPEGs.

Native platform: standard macOS runner, Xcode 16.4 (16F6), iPhone 16 Pro simulator
on iOS 18.5. Its independently measured prebuild source hash after dependency
setup is `46db2691e22f73c5657a7ec7b058a049a2a7c65b44e429b94bfc22abd2ef3053`. The Linux committed-source hash above
and native prebuild hash describe their respective measurement points; no
unverified claim of byte-for-byte equivalence is made.

## Remaining acceptance

The signed Bus Surge 1.1 TestFlight build/upload and physical-device verification
are pending. Live StoreKit sandbox, AdMob consent/ads, optional Game Center service
and store/privacy metadata are not certified by these tests. Real-money collection
sales are not enabled. App Store submission remains gated; internal TestFlight
is available after exact-main Actions succeeds.
