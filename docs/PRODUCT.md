# Bus Surge 1.1 — product rules

Source: Game #2 and standing release requirements in AI Casual Games Master Project,
read 6 October 2026. Scope: an offline, short-session iOS Flutter game, reusable for
Android later. This implements the color/queue/limited-parking variant.

## Board and transitions

1. Depot has three exits. Only each exit's front vehicle can move.
2. Three boarding spaces; bus capacity is shown on each vehicle. Routes 1–15
   use three seats; later lessons introduce two, four and six seats.
   Released buses occupy one space.
3. The single passenger queue is FIFO. The first passenger boards the oldest parked
   matching-color bus. Symbols duplicate the color distinction.
4. Boarding repeats until the queue head has no matching parked bus. Full vehicles
   depart immediately and free their space. Each accepted release is one move.
5. All passengers boarded and all vehicles departed = win. Full blocked parking,
   or no depot vehicles with passengers still waiting, = fail.
6. Failed/won states reject vehicle releases. Invalid indices/empty lanes are no-ops.
7. One continue adds a fourth space for the current attempt. Undo retains that space;
   restart begins the same board with its original three spaces.

## Generation and difficulty

Generator 2 begins with thirty authored lessons: blocked exits, reserved parking,
mixed passenger groups and different capacities. Wrong dispatches can fill the
terminal before the required bus is reachable. Further routes permute and combine
validated lessons, with a lighter route every five levels. An exact search finds
a winning witness with minimum parking cost, then executes it through the real
engine with seat/queue conservation at every move. Seeds and complete level
content persist. Generator-1 saves retain the original active board; newly opened
routes use version 2. Independent hints search the current board and never charge
for a non-existent solution. No network or paid AI generates levels.

Bus motion overlaps and never locks input. Stale gestures identify their original
front bus and cannot accidentally dispatch the next bus. A free Plan view exposes
the whole passenger queue and remaining bus order/capacities.

Parking cost sums waiting buses after each accepted move. Completion earns one
star; completion with original spaces earns two; meeting the exact parking target
without a hint earns three. Personal scores and stars keep their best results.
See [exact scoring and collection rules](REDESIGN.md).

## Currency/progression

Install grants 150 coins. First campaign completion grants 25 coins and unlocks the
next route; replay never re-awards those coins. Hints cost 25, the first undo in
an attempt is free, later undos cost 20, and extra space costs 50. Only successful
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
