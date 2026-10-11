# Bus Surge 2.0 — product rules

Source: Game #2 and standing release requirements in AI Casual Games Master Project,
read 6 October 2026. Scope: an offline, short-session iOS Flutter game, reusable for
Android later. This implements the crowd-to-bus variant with limited waiting slots.

## Board, generation and scoring

The crowd puzzle, generator 3 and scoring are specified in
[REDESIGN.md](REDESIGN.md). Extra slot, hints and undo keep the costs below.

## Currency/progression

Install grants 150 coins. First campaign completion grants 25 coins and unlocks the
next route; replay never re-awards those coins. Hints cost 25, the first undo in
an attempt is free, later undos cost 20, and extra slot costs 50. Only successful
assists charge. Restart is free. Rewarded video is
an optional alternative and grants only on SDK-earned-reward plus dismissal.
Concurrent requests are blocked; failed/cancelled/unavailable videos never grant
an assist or spend coins. A daily win awards 75 once per UTC calendar date. The
saved daily seed must match the date at completion; an expired daily cannot claim
a new day's reward. Consecutive UTC dates increment streak; gaps reset it to 1.
Daily mode preserves the exact campaign board/history. Campaign wins do not count
as daily wins. Garage purchases debit once and persist ownership and equipment.
Cosmetics preserve matching colours/symbols and never change rules. The catalogue
includes five bus liveries and four terminal styles, including free originals.
Collection real-money purchases are not enabled; stable identities prepare them.

All progress is local and survives relaunch; no cloud-sync promise. Game Center is
opt-in after account/provisioning setup. Only current-day daily scores without a
hint, undo or extra slot are submitted; offline records remain usable.

## Monetization, consent and telemetry

Interstitials occur only before advancing from a completed campaign route: route
6+, every fourth win, at least 180 seconds apart. Remote tuning enforces minimums
(route 6, every third win, 120 seconds). Remove Ads suppresses automatic ads only;
player-triggered rewarded videos remain optional. An unavailable ad never blocks
advancing. UMP authorization precedes ad initialization. No tracking permission
prompt is used to gate gameplay. Price comes from StoreKit; no hard-coded price.
Verified non-consumable purchase grants entitlement, cancellation/error does not,
pending stays pending, restore consults Apple's active entitlements, and revoked
transactions remove entitlement. Real SDK/sandbox behavior requires separate QA.

The bounded local analytics journal records session/start/move/win/fail, attempts,
assists, ad requests/impressions/revenue, purchase outcomes and lifecycle changes.
First install and active dates support retention analysis. Nothing is uploaded by
default; a central collector/dashboard has not been activated. Ad revenue depends
on configured AdMob and its actual impression-paid callbacks. Remote ad policy is
optional public HTTPS JSON via `REMOTE_CONFIG_URL`, with offline default fallback.
No notification permission, backend, paid API, paid asset, or billing plan is enabled.
