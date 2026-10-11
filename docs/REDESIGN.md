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
