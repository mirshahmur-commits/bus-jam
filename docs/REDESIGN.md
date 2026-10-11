# Bus Surge 2.0 — crowd puzzle

## Board

Passengers queue in three to five lanes inside a corridor that streams off
the bottom of the screen; the front of every lane faces the bus stop. Buses
arrive one at a time in a fixed order (the bus pill shows the line-up).
Every bus seats three passengers.

1. Tapping a lane sends its front passenger to the stop; the whole lane
   steps forward, so the crowd keeps flowing up from below.
2. A passenger whose colour matches the bus at the stop walks in and sits
   down. Anyone else takes the next free waiting slot (five slots).
3. A full bus leaves. The next bus pulls in and the matching waiting
   passengers board by themselves, in arrival order; this can fill and send
   away several buses.
4. Every bus departed = win. Five occupied slots = fail. Taps on empty
   lanes, and taps after the result, are no-ops.
5. Passengers marked **?** hide their colour until they reach the front.
6. The purple lock tile sells one extra slot for the attempt (coins or a
   rewarded video), while playing or after a jam. Undo retains it; restart
   returns to five slots.

## Generation

Generator 3 builds a random walk-out order over the lanes (each step takes
the front of a lane), colours that order by the bus sequence, then swaps
nearby colours for difficulty. Each candidate must be solved by the exact
solver with fewer slots than the player gets (three spare slots on levels
1–3, two to level 10, one to level 25, none afterwards; every fifth level is
a lighter breather). If no candidate passes, the unshuffled order is the
route. The witness is replayed through the real engine with save validation
at every move; seeds and full level content persist. Lines grow from three
short lanes (level 1) to five lanes of about fifteen passengers, colours
from two to six; hidden passengers start at level 8.

## Scoring

The waiting score adds the number of passengers in the slots after each tap.
The route target is the waiting score of the verified witness. One star means
completion, two mean no extra slot, three mean meeting the target without a
hint. Score is 1000 + max(0, 600 - 50 × excess) + 250 without the extra slot +
150 without a hint; maximum 2000. A new campaign route awards 25 coins once and
the current daily 75 once. Daily ranking accepts runs without hints, undos or
extra slots.

## Saves

Save schema 3 stores lane progress, waiting slots and bus progress. Schema 1
and 2 saves (depot puzzle) keep coins, unlocked routes, collection, settings,
streak and purchases and open the same route number as a crowd puzzle. Medals
earned on retired boards do not count toward crowd-route stars.

## Endless rush (2.1)

The main mode is an endless, real-time rush for a personal record.

- Four lanes; passengers never stop arriving at the back of random lanes.
  Arrivals start every 1.3 s and speed up with every bus sent and every
  second played (floor 0.38 s). Seven per lane open the run.
- Tap a lane: the front passenger boards the bus at the stop if the colour
  matches, otherwise waits in a slot. Full buses leave; matching waiting
  passengers board the next bus by themselves.
- The run ends when every waiting slot is taken (stop jammed) or a newcomer
  finds every lane full (crowd overflow).
- Fairness: each scheduled bus adds exactly its seat colours to an arrival
  bag; arrivals are drawn from about two buses ahead, so every passenger
  has a scheduled seat and arrivals roughly follow the bus order. Boosters
  that move passengers rebalance the bag so this stays true.
- Score: 10 per direct boarding plus a combo bonus (up to +20), 5 per
  passenger boarding from a slot or leaving by taxi, 25 per bus sent.
  Coins: one per 50 points, awarded once per run. Best score is saved.
- Boosters (coins, one starter of each): Rainbow — 30 s where anyone boards
  any bus (60); Slow-mo — 20 s of half-speed arrivals (40); Taxi — clears
  the waiting slots, also rescues a jammed run (50).
- Permanent upgrades: Bigger buses 4/5/6 seats (300/700/1500), Wider stop
  6/7 slots (400/1000), Calm crowd +0.25 s start pace (250/600).
- One extra slot per run for 50 coins (lock tile or after a jam).
- The rush pauses from the pause button and whenever the app leaves the
  foreground. Runs are not saved mid-way; coins are awarded when the run
  is settled (play again, shop, home or end run).
