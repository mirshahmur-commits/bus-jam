import 'package:bus_jam/game/model.dart';

/// A coral bus waits while the front row holds other colours. Five wrong
/// taps fill the waiting slots; the witness opens a path to the coral row.
Level trafficFixture() => Level(
  number: 12,
  seed: 12,
  rows: 2,
  cols: 6,
  cells: const [1, 1, 1, 2, 2, 2, 0, 0, 0, 3, 3, 3],
  buses: const [BusColor.coral, BusColor.blue, BusColor.gold, BusColor.mint],
  solution: const [0, 6, 7, 8, 1, 2, 3, 4, 5, 9, 10, 11],
);

/// Taps that fill all five waiting slots of [trafficFixture].
const trafficFailure = [0, 1, 2, 3, 4];
