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
- Use GitHub Actions on standard Linux for routine analysis and automated,
  business-rule/controller/widget tests. Keep iOS simulator/device acceptance
  and release verification in Codemagic. Never count skipped CI as passing.
- Before hosted CI runs, verify included allowance and blocked paid overage;
  only then set `ZERO_SPEND_CI_READY=true`. Do not add a payment method.

Current milestone: implemented Bus Jam candidate. Local automated and business
checks are executed; native iOS/sandbox evidence is still a required release gate.
