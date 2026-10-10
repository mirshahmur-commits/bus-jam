# Bus Surge 2.0 — crowd puzzle

## Board

A crowd stands on a grid below the bus stop; row 0 touches the stop. Buses
arrive one at a time in a fixed, visible order (Plan sheet: tap "buses").
Every bus seats three passengers.

1. A passenger can walk when they stand in row 0, or next to open pavement
   connected to row 0. Others are blocked and drawn slightly darker.
2. A walking passenger whose colour matches the bus at the stop boards it.
   Anyone else takes the next free waiting slot (five slots).
3. A full bus leaves. The next bus pulls in and collects matching waiting
   passengers in arrival order; this can fill and send away several buses.
4. Every bus departed = win. Five occupied slots = fail. Taps on blocked
   or empty cells, and taps after the result, are no-ops.
5. Passengers marked **?** hide their colour until their path is open.
6. One continue adds a sixth slot for the attempt. Undo retains it; restart
   returns to five slots.

## Generation

Generator 3 removes the crowd in a random walk-out order (each step frees a
reachable passenger), colours that order by the bus sequence, then swaps
nearby colours for difficulty. Each candidate must be solved by the exact
solver with fewer slots than the player gets (three spare slots on routes
1–3, two to route 10, one to route 25, none afterwards; every fifth route is a
lighter breather). If no candidate passes, the unshuffled order is the route.
The witness is replayed through the real engine with save validation at every
move; seeds and full level content persist. Crowds grow from 3×3 (route 1) to
7×6, colours from two to six; hidden passengers start at route 8.

## Scoring

The waiting score adds the number of passengers in the slots after each tap.
The route target is the waiting score of the verified witness. One star means
completion, two mean no extra slot, three mean meeting the target without a
hint. Score is 1000 + max(0, 600 - 50 × excess) + 250 without the extra slot +
150 without a hint; maximum 2000. A new campaign route awards 25 coins once and
the current daily 75 once. Daily ranking accepts runs without hints, undos or
extra slots.

## Saves

Save schema 3 stores the crowd board, waiting slots and bus progress. Schema 1
and 2 saves (depot puzzle) keep coins, unlocked routes, collection, settings,
streak and purchases and open the same route number as a crowd puzzle. Medals
earned on retired boards do not count toward crowd-route stars.
