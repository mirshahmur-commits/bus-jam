# GitHub Actions / Codemagic / Apple setup

Repository: `mirshahmur-commits/bus-jam`. iOS first; no owner Mac required.

## Pipeline

1. Push/PR: GitHub Actions runs formatting, analysis, business/controller/widget
   tests, 10,000 generated levels, release web compilation and CI-gate tests on Linux.
2. After Linux passes, a standard `macos-15` Actions runner boots an iPhone
   simulator, runs the native player journey, saves five screenshots and compiles
   the normal simulator app. No signing account is required for these tests.
3. On `main`, wait for both **quality** and **iOS simulator acceptance** to pass.
4. In Codemagic, manually start the only workflow, **ios-testflight**, on that
   exact main commit. It checks GitHub's completed run and both successful jobs,
   prepares build dependencies/signing, builds IPA and uploads to internal TestFlight.
   It does not run tests. Failed, missing, pending or skipped Actions jobs block it.
5. Real-device StoreKit/AdMob verification follows on the signed TestFlight build.
   `tool/release_gate.py` still blocks App Store release until those results and
   privacy/store metadata are complete. Internal TestFlight does not require those
   post-upload checks to have already run.

## Owner-only account configuration

1. Apple Developer: create App ID `com.systemcraft.busJam` with In-App Purchase.
2. App Store Connect: create the app with that Bundle ID and an available display name.
   Bus Jam is a working title; name availability is not claimed.
3. Create non-consumable `com.systemcraft.busJam.remove_ads`, set price/localizations,
   agreements/tax/banking if needed, and a sandbox tester.
4. Add the repository in Codemagic. Reuse an existing App Store Connect API key
   with access to this app. Match its integration name to **systemcraft-app-store**
   in YAML, or update that name to your existing integration. Keep keys there.
5. Use the personal M2 included allowance with billing disabled. Set
   `ZERO_SPEND_CI_READY=true` after allowance verification. No paid overage, payment
   method, or automatic paid minutes. The already checked included allowance is
   500 M2 minutes/month; Codemagic is now used only for signed builds/uploads.
6. Start **ios-testflight** only after Actions is green for the selected main commit.
   The public repository's standard Linux/macOS Actions runners are free.
   Native evidence uploads are capped at 16 MiB and retained for one day; keep
   billing disabled and preserve useful native evidence before it expires.
7. Leave ad units unset for the initial offline TestFlight candidate. For AdMob QA,
   configure Google test units/devices, consent and full/close/fail/offline flows.
   Use `ADMOB_REWARDED_ID` / `ADMOB_INTERSTITIAL_ID` environment values for builds.
   Before production, replace sample app IDs and check SDK/privacy declarations.
8. On the signed TestFlight build, verify StoreKit price/purchase/cancel/pending,
   reinstall/restore, offline entitlement and revocation. Mocks are not sandbox evidence.
9. Complete privacy/support URLs, age rating, descriptions/screenshots, ad/data
   disclosures and SKAdNetwork setup. Record matching candidate evidence in release
   readiness before any App Store release. Store submission is disabled in YAML.

## Commands

The pinned `google_mobile_ads` 6 dependency graph requires CocoaPods for all iOS
plugins. `flutter.config.enable-swift-package-manager: false` in `pubspec.yaml`
prevents its WebView dependency from being split across native resolvers in both
Actions and Codemagic. Re-enable SwiftPM when upgrading to a compatible ad plugin.

```sh
bash tool/quality_gate.sh
python3 -m unittest discover -s tool/tests -v
bash tool/run_ios_uat.sh  # macOS; executed by Actions
python3 tool/verify_actions.py  # read-only gate on a real main checkout
python3 tool/source_identity.py
python3 tool/release_gate.py    # full App Store readiness; separate from TestFlight
```

A private repository requires checking its allowance and blocked overage before
enabling CI. A skipped job never passes the TestFlight gate.
Android billing/signing/device acceptance remains a later platform task.

Sources: https://docs.github.com/en/actions/reference/runners/github-hosted-runners,
https://docs.github.com/en/rest/actions/workflow-runs,
https://docs.github.com/en/rest/actions/workflow-jobs,
https://docs.codemagic.io/billing/pricing/,
https://developers.google.com/admob/flutter/privacy,
https://developer.apple.com/documentation/storekit/transaction/currententitlements.
