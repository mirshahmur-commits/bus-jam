import 'package:bus_jam/game/model.dart';

/// A coral bus waits while every lane starts with another colour. Five
/// wrong taps fill the waiting slots; the witness digs out the coral riders.
Level trafficFixture() => Level(
  number: 12,
  seed: 12,
  lanes: const [
    [1, 0, 0],
    [1, 0, 2],
    [1, 2, 2],
    [3, 3, 3],
  ],
  buses: const [BusColor.coral, BusColor.blue, BusColor.gold, BusColor.mint],
  solution: const [0, 0, 0, 1, 1, 2, 1, 2, 2, 3, 3, 3],
);

/// Lane taps that fill all five waiting slots of [trafficFixture].
const trafficFailure = [0, 1, 2, 3, 3];

/// Lane taps that win [trafficFixture] after [trafficFailure] and one
/// extra slot.
const trafficRecovery = [0, 0, 1, 1, 2, 2, 3];
