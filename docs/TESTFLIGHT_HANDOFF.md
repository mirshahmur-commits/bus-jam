# Bus Surge 2.0 — internal TestFlight handoff

## Automated acceptance

- GitHub Actions `quality`: formatting, static analysis, Flutter tests, and 10,000 generated levels.
- GitHub Actions `iOS simulator acceptance`: iOS simulator launch and UI acceptance.
- Codemagic `ios-testflight` refuses to build unless **both jobs passed on the exact main-branch commit**. Do not run Codemagic against the feature branch.
- The release must use a fresh monotonically increasing iOS build number; Codemagic supplies `PROJECT_BUILD_NUMBER`.

## One-time Apple configuration

1. In Apple Developer, register App ID `com.systemcraft.busJam` with the appropriate capabilities (Game Center if enabled).
2. In App Store Connect, create the iOS app for this Bundle ID, configure the app name **Bus Surge**, internal testing group and internal testers. Accept agreements and complete required compliance questions.
3. In Codemagic, connect the **App Store Connect API key** integration named `MiniPoliglotKey` (or change the integration name in `codemagic.yaml` to match the account).
4. Set up automatic App Store signing for `com.systemcraft.busJam`. Confirm the signing certificate and provisioning profile cover the same Bundle ID and capabilities.
5. Create the Codemagic environment group `bus_jam_build`. Configure `GITHUB_READ_TOKEN` only if unauthenticated GitHub API calls cannot read the public workflow results; grant minimum read-only permissions. Optional: `GAME_CENTER_LEADERBOARD_ID`, `ADMOB_REWARDED_ID`, `ADMOB_INTERSTITIAL_ID`.
6. **Ads:** `ios/Runner/Info.plist` currently contains Google's sample AdMob app ID. This is acceptable for internal development only. Before any public App Store release, replace it with the production app ID and validate consent, test devices, real ad-unit IDs and privacy disclosures. Do not expose production ad-unit IDs without the matching app ID.

## Exact release procedure

1. Review PR #5, wait until all required GitHub Actions jobs are green, and merge to `main`.
2. Wait for the **main push** workflow to complete successfully. A successful feature-branch workflow does not satisfy the Codemagic gate.
3. In Codemagic, choose the `ios-testflight` workflow on `main`, then **Start new build**.
4. Verify that the first script, `Verify successful GitHub Actions for this commit`, reports `Passed`.
5. Confirm the signed `.ipa` artifact and the App Store Connect publishing step both succeed.
6. Open App Store Connect → TestFlight → Builds. Wait for Apple processing and any compliance prompts; add the build to the internal testing group. Install it using TestFlight on a real iPhone.

## Real-device acceptance before inviting external testers

- First launch, tutorial, tap response, and three consecutive fast taps.
- Finish and fail levels; continue, undo, hint, replay and return to home.
- Play levels 1–15, 30, 31–35; verify actual risk of blocking parking, readable passengers and bus occupancy.
- Test narrow iPhone layout, safe areas, animation, audio/haptics and reduced motion.
- Force-close and relaunch: progress, coins, cosmetics, daily state and record persist.
- Offline launch and play; no crash when Game Center, ads or network are unavailable.
- Confirm Game Center sign-in and leaderboard submission if the leaderboard is configured.
- Test rewarded ad and interstitial flows only when the appropriate ad configuration is enabled.
- Check screenshots, App Privacy disclosures, age rating and in-app purchase metadata before public release.

## Release blockers

Do not claim the build is uploaded merely because GitHub Actions passed. A successful Codemagic build, successful publishing and visibility of the processed build in App Store Connect are separate requirements. The App Store Connect account owner must finish any required Apple-side agreements, compliance or tester setup.
