# GitHub / Codemagic / Apple setup

Repository: `mirshahmur-commits/bus-jam`. iOS first; no local Mac required.

## Owner-only account configuration

1. Apple Developer: create App ID `com.systemcraft.busJam` with In-App Purchase.
2. App Store Connect: create the app using that Bundle ID and an available store
   display name (Bus Jam is a working title; name availability is not claimed).
3. Create a non-consumable `com.systemcraft.busJam.remove_ads`, set price/localizations,
   and complete agreements/tax/banking if monetization is desired. Create a sandbox tester.
4. Codemagic: add this GitHub app; connect an App Store Connect API key as integration
   **`systemcraft-app-store`**. Keep key/certificate material in Codemagic only.
5. Use a **personal M2** account; check remaining included minutes and leave billing
   disabled. Set `ZERO_SPEND_CI_READY=true` only after this check. Documentation checked
   6 Oct 2026: personal M2 includes 500 minutes/month; team and Linux/Windows minutes
   are not the free allowance. Do not buy minutes or add a payment method.
6. Select **ios-qa** manually. It runs all tests, a real iPhone simulator journey,
   captures native screenshots and builds a simulator app. Preserve results for the
   exact candidate identity. This first native workflow has not run from this workspace.
7. Native ads: test with Google's test ad units/test devices, exercise UMP consent,
   full viewing/dismissal/no-fill/offline and duplicate callback protection. Set the
   Dart defines `ADMOB_REWARDED_ID` / `ADMOB_INTERSTITIAL_ID` for the relevant test run.
   Final distribution requires replacing sample app IDs in Info.plist/AndroidManifest,
   setting live unit IDs and reviewing the current SDK/store privacy declarations.
8. StoreKit: on a signed candidate/sandbox tester, verify price, purchase/cancel/pending,
   restore after reinstall, offline entitlement and revocation behavior. Mock results
   do not satisfy this gate. Use a QA build rather than unblocking release prematurely.
9. Complete privacy URL, support URL, age/content rating, screenshots, descriptions,
   ad/data disclosures and current SKAdNetwork setup. Review `docs/UAT.md`.
10. Update release readiness with actual evidence and **matching source hash**, rerun
    required checks, then use `ios-testflight`. The gate blocks today. Store submission
    is disabled in YAML (`submit_to_app_store: false`); publication is a separate step.

## Commands

```sh
bash tool/quality_gate.sh
bash tool/run_ios_uat.sh       # macOS + available iPhone simulator
python3 tool/source_identity.py
python3 tool/release_gate.py  # expected to block until native/sandbox evidence exists
```

iOS QA artifacts live under `test-results/`. You do not have to write code or execute
routine manual test cases yourself; account access/configuration is the remaining
owner involvement. Android billing/signing/device UAT is outside the current iOS-first
candidate. The committed Android template signs debug builds only; do not publish it.

Sources: https://docs.codemagic.io/billing/pricing/,
https://docs.codemagic.io/yaml-testing/testing/,
https://docs.github.com/en/billing/concepts/product-billing/github-actions,
https://developers.google.com/admob/flutter/privacy,
https://developer.apple.com/documentation/storekit/transaction/currententitlements.
