import 'dart:math';

import 'engine.dart';
import 'model.dart';

/// Deterministic crowd generator. A random walk-out order over the lanes is
/// coloured by the bus sequence, then locally shuffled for difficulty. Every
/// candidate is verified by the exact solver with fewer waiting slots than
/// the player gets, and the witness is replayed through the real engine.
class LevelGenerator {
  static const version = 3;
  final _cache = <String, Level>{};

  static const _titles = [
    'Morning rush',
    'Market street',
    'School run',
    'Harbour stop',
    'Park gate',
    'Station square',
    'Stadium night',
    'Museum loop',
    'Festival lane',
    'Airport shuttle',
  ];

  static String _lesson(int n) => switch (n) {
    1 => 'Tap a lane. Its front passenger walks to the matching bus.',
    2 => 'Wrong colours wait in the slots. Five full slots jam the stop.',
    3 => 'Waiting passengers hop on by themselves when their bus arrives.',
    4 => 'A full bus leaves and the next one pulls in.',
    5 => 'Check the next bus on the left before you send someone to wait.',
    8 => 'Passengers marked ? reveal their colour at the front of the line.',
    _ => const [
      'Look at the next bus before you send someone to wait.',
      'Dig into a lane for the colour the next buses need.',
      'Keep at least two slots open when you can.',
      'A crowded slot row is fine if their bus is next.',
    ][n % 4],
  };

  Level generate(int number, {int? seed}) {
    if (number < 1) throw ArgumentError.value(number);
    final actualSeed = seed ?? number * 7919 + 104729;
    final key = '$number/$actualSeed';
    if (_cache.containsKey(key)) return _cache[key]!;
    final rng = Random(actualSeed);
    final breather = number % 5 == 0;
    final laneCount = number <= 2
        ? 3
        : number <= 30
        ? 4
        : 5;
    final busTotal = min(
      24,
      (number <= 2 ? 2 + number : 4 + number ~/ 2) - (breather ? 2 : 0),
    );
    final colorCount = min(
      busTotal,
      number <= 2
          ? 2
          : number <= 6
          ? 3
          : number <= 14
          ? 4
          : number <= 30
          ? 5
          : 6,
    );
    final margin = number <= 3
        ? 3
        : number <= 10
        ? 2
        : number <= 25 || breather
        ? 1
        : 0;
    final hard = !breather && number > 25 && number % 3 == 0;
    var shuffle = min(.65, .15 + number * .02) * (breather ? .5 : 1);
    if (hard) shuffle = min(.8, shuffle + .15);

    // Bus sequence: balanced colours, never three equal buses in a row.
    final palette = BusColor.values.toList()..shuffle(rng);
    final colors = palette.take(colorCount).toList();
    final buses = <BusColor>[
      for (int b = 0; b < busTotal; b++) colors[b % colors.length],
    ]..shuffle(rng);
    for (int b = 2; b < buses.length; b++) {
      if (buses[b] == buses[b - 1] && buses[b] == buses[b - 2]) {
        final swap = (b + 1 + rng.nextInt(buses.length)) % buses.length;
        final t = buses[b];
        buses[b] = buses[swap];
        buses[swap] = t;
      }
    }
    final people = busTotal * busCapacity;

    // Lane depths: an even split with a little variation.
    final depths = List.filled(laneCount, people ~/ laneCount);
    for (int i = 0; i < people % laneCount; i++) {
      depths[i]++;
    }
    for (int k = 0; k < laneCount; k++) {
      final a = rng.nextInt(laneCount), b = rng.nextInt(laneCount);
      if (a != b && depths[a] > 2) {
        depths[a]--;
        depths[b]++;
      }
    }

    // Walk-out order: repeatedly take the front of a random lane.
    final order = <int>[];
    final left = depths.toList();
    while (order.length < people) {
      final lane = rng.nextInt(laneCount);
      if (left[lane] == 0) continue;
      left[lane]--;
      order.add(lane);
    }

    final stream = [
      for (final bus in buses) ...List.filled(busCapacity, bus.index),
    ];
    Level? level;
    for (int attempt = 0; attempt < 10 && level == null; attempt++) {
      final strength = attempt == 9 ? 0.0 : shuffle * (1 - attempt * .1);
      final colours = stream.toList();
      final window = 3 + min(6, number ~/ 6).toInt();
      for (int t = 0; t < colours.length; t++) {
        if (rng.nextDouble() < strength) {
          final u = min(colours.length - 1, t + 1 + rng.nextInt(window));
          final swap = colours[t];
          colours[t] = colours[u];
          colours[u] = swap;
        }
      }
      final lanes = [for (final _ in depths) <int>[]];
      for (int t = 0; t < order.length; t++) {
        lanes[order[t]].add(colours[t]);
      }
      final hidden = <int>{};
      if (number >= 8) {
        final share = min(.3, .08 + number * .004);
        for (int lane = 0; lane < lanes.length; lane++) {
          for (int d = 1; d < lanes[lane].length; d++) {
            if (rng.nextDouble() < share) hidden.add(Level.key(lane, d));
          }
        }
      }
      final draft = Level(
        number: number,
        seed: actualSeed,
        lanes: lanes,
        buses: buses,
        hidden: hidden,
      );
      final tight = Board(
        taken: List.filled(lanes.length, 0),
        waiting: const [],
        busIndex: 0,
        boarded: 0,
        moves: 0,
        slots: draft.slots - margin,
      );
      // Without a shuffle the walk-out order itself is a direct route.
      final route = strength == 0
          ? order
          : GameEngine.solve(draft, tight, maxStates: 6000);
      if (route == null) continue;
      level = Level(
        number: number,
        seed: actualSeed,
        lanes: lanes,
        buses: buses,
        hidden: hidden,
        solution: route,
        title: seed != null
            ? 'Daily rush'
            : number == 1
            ? 'First stop'
            : _titles[(number - 2) % _titles.length],
        lesson: _lesson(number),
        parkingTarget: GameEngine.waitingCost(draft, route),
        hard: hard,
      );
    }
    if (level == null) throw StateError('Unsolvable generated level $number');
    var board = Board.initial(level);
    for (final lane in level.solution) {
      final move = GameEngine.tap(level, board, lane);
      if (!move.accepted) throw StateError('Blocked generator witness');
      board = move.board;
      board.validate(level);
    }
    if (board.phase(level) != GamePhase.won) {
      throw StateError('Invalid generator witness');
    }
    if (_cache.length >= 32) _cache.remove(_cache.keys.first);
    _cache[key] = level;
    return level;
  }

  Level daily(DateTime date) {
    final utc = date.toUtc();
    return generate(24, seed: utc.year * 10000 + utc.month * 100 + utc.day);
  }
}
