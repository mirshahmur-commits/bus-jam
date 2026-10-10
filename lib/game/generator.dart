import 'dart:math';

import 'engine.dart';
import 'model.dart';

/// Deterministic crowd generator. A random walk-out order of the crowd is
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
    1 => 'Tap a passenger with a clear path. Matching colours board the bus.',
    2 => 'Wrong colours wait in the slots. Five full slots end the route.',
    3 => 'Clear the front row to open a path for the crowd behind.',
    4 => 'Waiting passengers board by themselves when their bus arrives.',
    5 => 'A full bus leaves and the next one pulls in.',
    8 => 'Passengers marked ? reveal their colour once their path opens.',
    _ => const [
      'Look at the next bus before you send someone to wait.',
      'Free the passengers the next buses need.',
      'Keep at least two slots open when you can.',
      'Open paths early so hidden passengers reveal themselves.',
    ][n % 4],
  };

  Level generate(int number, {int? seed}) {
    if (number < 1) throw ArgumentError.value(number);
    final actualSeed = seed ?? number * 7919 + 104729;
    final key = '$number/$actualSeed';
    if (_cache.containsKey(key)) return _cache[key]!;
    final rng = Random(actualSeed);
    final breather = number % 5 == 0;
    final cols = number <= 2
        ? 3
        : number <= 6
        ? 4
        : number <= 15
        ? 5
        : 6;
    final rows = min(7, 3 + (number - 1) ~/ 5);
    final colorCount = number <= 2
        ? 2
        : number <= 6
        ? 3
        : number <= 14
        ? 4
        : number <= 30
        ? 5
        : 6;
    final margin = number <= 3
        ? 3
        : number <= 10
        ? 2
        : number <= 25 || breather
        ? 1
        : 0;
    var shuffle = min(.65, .12 + number * .02) * (breather ? .5 : 1);
    final hard = !breather && number > 25 && number % 3 == 0;
    if (hard) shuffle = min(.8, shuffle + .15);

    // Shape: a full rectangle minus a few holes, rounded to whole buses.
    final cellCount = rows * cols;
    var holes = number <= 2 ? 0 : rng.nextInt(cols ~/ 2 + 1);
    var people = cellCount - holes;
    people -= people % busCapacity;
    holes = cellCount - people;
    final filled = List.filled(cellCount, true);
    final candidates = [for (int i = cols; i < cellCount; i++) i]..shuffle(rng);
    for (int h = 0; h < holes; h++) {
      filled[candidates[h]] = false;
    }

    // Bus sequence: balanced colours, never three equal buses in a row.
    final palette = BusColor.values.toList()..shuffle(rng);
    final colors = palette.take(colorCount).toList();
    final busTotal = people ~/ busCapacity;
    final buses = <BusColor>[];
    for (int b = 0; b < busTotal; b++) {
      var pick = colors[b < colors.length ? b : rng.nextInt(colors.length)];
      while (buses.length >= 2 &&
          buses[buses.length - 1] == pick &&
          buses[buses.length - 2] == pick) {
        pick = colors[rng.nextInt(colors.length)];
      }
      buses.add(pick);
    }
    if (busTotal > colors.length) buses.shuffle(rng);

    // Walk-out order: repeatedly free a random reachable passenger.
    final order = <int>[];
    final template = Level(
      number: number,
      seed: actualSeed,
      rows: rows,
      cols: cols,
      cells: [for (final f in filled) f ? buses.first.index : -1],
      buses: [for (int i = 0; i < people ~/ busCapacity; i++) buses.first],
    );
    var shape = Board.initial(template);
    while (order.length < people) {
      final options = shape.reachable(template).toList()..sort();
      final cell = options[rng.nextInt(options.length)];
      order.add(cell);
      final next = shape.people.toList()..[cell] = -1;
      shape = Board(
        people: next,
        waiting: const [],
        busIndex: 0,
        boarded: 0,
        moves: 0,
        slots: template.slots,
      );
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
      final cells = List.filled(cellCount, -1);
      for (int t = 0; t < order.length; t++) {
        cells[order[t]] = colours[t];
      }
      final hidden = <int>{};
      if (number >= 8) {
        final share = min(.28, .06 + number * .004);
        for (int i = cols; i < cellCount; i++) {
          if (cells[i] >= 0 && rng.nextDouble() < share) hidden.add(i);
        }
      }
      final draft = Level(
        number: number,
        seed: actualSeed,
        rows: rows,
        cols: cols,
        cells: cells,
        buses: buses,
        hidden: hidden,
      );
      final initial = Board.initial(draft);
      final tight = Board(
        people: initial.people,
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
        rows: rows,
        cols: cols,
        cells: cells,
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
    for (final cell in level.solution) {
      final move = GameEngine.tap(level, board, cell);
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
