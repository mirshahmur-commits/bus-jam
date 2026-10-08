# Standing project instructions

- Develop this game in Flutter and Dart. Ship iOS first; reuse the code for Android later.
- The owner has an Apple Developer account, has no Mac, and uses Codemagic for iOS builds and uploads.
- The assistant owns design, code, debugging, tests, CI and release preparation. Ask the owner only for account access or owner-only actions.
- Spend no additional money. Use free tools and quotas, no paid assets or APIs, no automatic billing and no paid acquisition.
- Run automated, business-rule and assistant-executed acceptance tests before every publication. Keep evidence for the exact build. Never mark unexecuted checks passed.
- Gate distribution on passing required checks and resolving release-blocking defects. Preserve `release-readiness.json` while the project is a prototype.
- Optimize for a commercially useful game: a clear hook, retention, replayability, restrained ad frequency, rewarded ads and optional Remove Ads.
- Keep domain rules separate from Flutter, storage, analytics and future monetization adapters.
- Procedural levels must remain deterministic and solvable. Version generator changes and migrate saves rather than silently changing boards.
- Do not use private work-project names in examples or assets.
- Keep credentials out of git and logs. Do not access instance metadata or other unrelated sensitive sources.
- No sub-agents are requested for this project.
- Run every automated test in GitHub Actions: Linux for analysis, rules,
  business/controller/widget tests and generation; standard macOS for native
  iPhone simulator UAT and compilation. Codemagic only signs, builds and uploads
  to TestFlight after checking successful Actions for the exact main commit.
  Never count skipped CI as passing. Internal TestFlight enables subsequent
  real-device StoreKit/AdMob verification; App Store release remains gated.
- Codemagic uses the owner's existing free plan and its quota cap. Do not add
  a manual allowance-confirmation flag or step to Codemagic. Preserve the
  exact-commit Actions gate. Do not enable paid billing.
- A private GitHub repository requires checking its included allowance and
  blocked paid overage before enabling CI.

Current milestone: automated/business/widget and native iPhone simulator checks
passed in Actions. Signed TestFlight/device and real provider acceptance remain
required for App Store release.
