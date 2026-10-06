# Acceptance journeys and expected outcomes

Local executed outcomes are in TEST_REPORT.md; iOS execution is a separate gate.

| ID | Player action | Expected outcome |
| --- | --- | --- |
| UAT-01 | First install → Play → onboarding → solve → Next | One short tutorial; legal boarding/departure; win; +25; route 2 |
| UAT-02 | Release three wrong buses → continue → solve | Full parking produces fail; one extra space for 50; boarding frees spaces; win |
| UAT-03 | Hint → move → Undo → Restart → settings | Solver-highlighted bus; exact rollback; same fresh board; persisted toggles |
| UAT-04 | Daily → Home → route map → locked route | Campaign survives detour; unavailable routes cannot be tapped |
| UAT-05 | Request video while provider unavailable | No reward or debit; readable message; game continues |
| UAT-06 | Partial play → background/save → relaunch | Exact passenger cursor, bus state and undo/progress restored |
| UAT-07 | 320×568, 375×667, 390×844, 430×932, 768×1024 | No overflow/exceptions; controls scroll into view; settings remain readable |
| UAT-08 | Win/replay/daily same day | No duplicate campaign/daily coin award |
| UAT-09 | Native purchase → cancel/pending/restore/revoke | Grant only verified entitlement, localized price; correct restoration |
| UAT-10 | Native rewarded: full/close/fail/offline | Earned callback grants once; all unsuccessful paths grant zero |
| UAT-11 | Native consent/privacy choices | Requests only when UMP permits; privacy controls reopen appropriately |
| UAT-12 | Remove Ads → play past ad cadence | Automatic ads suppressed; optional rewarded path retained |

Native run: `tool/run_ios_uat.sh` + `integration_test/app_test.dart`, with actual
screenshots via integration driver. The scripted native journey uses a deterministic
traffic fixture to exercise failure/recovery; it does not test real paid transactions.

Before release, visually inspect native screenshots, colors/symbols, touch targets,
notches/safe areas and reduced motion on supported iPhones; verify native audio,
haptics, foreground/background and force-quit/relaunch, performance and storefront
paths on the signed candidate. Mark unavailable checks **Not run**, never Passed.
