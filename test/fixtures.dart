import 'package:bus_jam/game/model.dart';

Level trafficFixture() => Level(
  number: 12,
  seed: 12,
  lanes: [
    [
      const Bus(0, BusColor.blue),
      const Bus(1, BusColor.gold),
      const Bus(2, BusColor.mint),
      const Bus(3, BusColor.coral),
    ],
    [const Bus(4, BusColor.coral)],
  ],
  passengers: [
    ...List.filled(3, BusColor.coral),
    ...List.filled(3, BusColor.blue),
    ...List.filled(3, BusColor.gold),
    ...List.filled(3, BusColor.mint),
    ...List.filled(3, BusColor.coral),
  ],
  solution: [1, 0, 0, 0, 0],
);
