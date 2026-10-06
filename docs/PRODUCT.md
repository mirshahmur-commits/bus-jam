# Bus Jam 1.0 — product rules

Source: Game #2 and standing release requirements in AI Casual Games Master Project,
read 6 October 2026. Scope: an offline, short-session iOS Flutter game, reusable for
Android later. This implements the color/queue/limited-parking variant.

## Board and transitions

1. Depot has 2 tutorial lanes, then 3 lanes. Only each lane's front vehicle can move.
2. Three boarding spaces; vehicles have three seats. Released buses occupy one space.
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

Generator v1 builds waves of 1–3 buses with matching passenger totals, assigns buses
to ordered depot lanes, then interleaves each wave's passengers. Its recorded release
sequence is replayed through the real engine with seat/queue conservation validated
at every move. Seeds and full level content persist in saves. Generator migrations
must be explicit. Independent state-search hints are calculated from the current
board, never blindly from the original witness. A dead end recommends undo/restart
without charging for a non-existent hint.

Routes 1–2 teach immediate matching, routes 3–4 introduce staged vehicles, route 5+
interleaves passengers. Colors and wave count rise gradually to a capped layout.
District titles cycle every 10 levels. No network or paid AI is used for generation.

## Currency/progression

Install grants 150 coins. First campaign completion grants 25 coins and unlocks the
next route; replay never re-awards those coins. Hints cost 25, undo costs 20, extra
space costs 50. Only successful assists charge. Restart is free. Rewarded video is
an optional alternative and grants only on SDK-earned-reward plus dismissal.
Concurrent requests are blocked; failed/cancelled/unavailable videos never grant
an assist or spend coins. A daily win awards 75 once per local calendar date. The
saved daily seed must match the date at completion; an expired daily cannot claim
a new day's reward. Consecutive local dates increment streak; gaps reset it to 1.
Daily mode preserves the exact campaign board/history. Campaign wins do not count
as daily wins. All state is local and survives relaunch; no cloud-sync promise.

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
