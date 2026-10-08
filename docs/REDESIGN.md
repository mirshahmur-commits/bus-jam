# Bus Surge 1.1 candidate

The first thirty routes introduce release ordering, blocked exits, terminal
reservation, mixed passenger groups and different bus capacities. Every route
has an executed winning witness and an exact minimum parking occupancy target.
Further routes combine certified lessons, rotate colours and exits, and insert
a lighter route every five levels. They stay deterministic within generator 2.

Input is independent of motion. Buses move in 260 ms and departing buses leave
in 440 ms; their motions overlap. Retargeting uses the current rendered position.
Gesture identity rejects a stale front bus rather than releasing a different one.
These durations are implementation settings, not measurements of device latency.

Parking cost sums settled waiting buses after each accepted move. One star means
completion, two mean original spaces, and three mean meeting the exact target
without hints. A free undo is available once per attempt and preserves medals.
Score is 1000 + max(0, 600 - 50 * excess parking cost), plus 250 for original
spaces and 150 without a hint. Maximum score is 2000. Winning again cannot farm
coins: a new campaign route awards 25 once; the current daily awards 75 once.

Personal records and dispatcher tiers are local: 15, 45 and 90 campaign stars.
The daily puzzle uses one UTC date seed. Game Center accepts only current-day
results without hints, undos or extra slots. Assisted results remain personal.
No invented opponents or global ranks appear in the offline interface.

The garage has five bus liveries and four terminal styles, including free
originals. Coin purchase is atomic, ownership prevents repeat debit and only
owned cosmetics can be equipped. Route colours, symbols, seats and game rules
remain unchanged by cosmetics. Stable product IDs prepare future non-consumable
collections; real-money collection sales are not enabled in this version.

Save schema 2 retains currency, unlocked routes, preferences, undo history and
the exact embedded generator-1 board, including an active campaign during a
daily excursion. New routes use generator 2. Existing completion history does
not fabricate stars for newly designed boards. Ownership, equipment, results,
ranked daily scores and per-attempt assist use survive relaunch.

Validation includes meaningful-choice checks for the campaign, 10000 executed
procedural witnesses and scoring targets, business rules, rapid-input widgets,
five display sizes, a coin-earned native collection purchase/restore journey,
and seven iPhone screenshots. Exact run results are generated in Actions;
historical 1.0 screenshots and reports do not certify this candidate.

## Optional Game Center setup

The default build uses personal records and requires no change to the existing
signing profile. To enable the online daily board:

1. Enable Game Center for `com.systemcraft.busJam` in Apple Developer and
   refresh its App Store provisioning profile in Codemagic.
2. In App Store Connect create a recurring leaderboard with ID
   `com.systemcraft.busJam.daily`, integer scores, descending order, range
   0–2000, best score, and daily duration/reset beginning at 00:00 UTC. Attach
   it to the app version's Game Center configuration.
3. Add `GAME_CENTER_LEADERBOARD_ID=com.systemcraft.busJam.daily` to the existing
   `bus_jam_build` group. The committed YAML configures the entitlement and
   passes the ID; do not manually edit YAML.
4. Test signing, sign-in, dismissal, a clean score, assisted-run exclusion and
   day rollover on a real TestFlight device before release. Automated tests and
   simulator compilation do not certify the Apple account/service setup.

Collection IAP can later map catalog `productId` values to verified StoreKit
non-consumables with restore/revocation handling. Coin ownership must remain
valid when IAP is added; duplicate ownership must not trigger another charge.
