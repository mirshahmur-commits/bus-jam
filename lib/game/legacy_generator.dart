import 'dart:math';

import 'engine.dart';
import 'model.dart';

class LegacyLevelGenerator {
  static const version = 1;
  Level generate(int number, {int? seed}) {
    if (number < 1) {
      throw ArgumentError.value(number);
    }
    final actualSeed = seed ?? number * 7919 + 104729;
    final rng = Random(actualSeed);
    final colors = (BusColor.values.toList()..shuffle(rng))
        .take(min(6, 2 + number ~/ 8))
        .toList();
    final lanes = List.generate(number < 4 ? 2 : 3, (_) => <Bus>[]);
    final passengers = <BusColor>[];
    final solution = <int>[];
    final waves = min(6, 2 + number ~/ 6);
    var id = 0;
    for (int wave = 0; wave < waves; wave++) {
      final groupSize = number <= 2
          ? 1
          : min(3, 2 + (number >= 12 && wave.isOdd ? 1 : 0));
      final waveColors = (colors.toList()..shuffle(rng))
          .take(groupSize)
          .toList();
      if (number <= 2) {
        waveColors[0] = colors[wave % colors.length];
      }
      final wavePassengers = <BusColor>[];
      for (final color in waveColors) {
        final lane = rng.nextInt(lanes.length);
        lanes[lane].add(Bus(id++, color));
        solution.add(lane);
        wavePassengers.addAll(List.filled(3, color));
      }
      if (number >= 5) {
        wavePassengers.shuffle(rng);
      }
      passengers.addAll(wavePassengers);
    }
    final level = Level(
      number: number,
      seed: actualSeed,
      lanes: lanes,
      passengers: passengers,
      solution: solution,
    );
    // Construction alone is not considered proof: execute the witness.
    var board = Board.initial(level);
    for (final lane in solution) {
      final result = GameEngine.release(level, board, lane);
      if (!result.accepted) {
        throw StateError('Generator produced a blocked witness');
      }
      board = result.board;
      board.validate(level);
    }
    if (board.phase(level) != GamePhase.won) {
      throw StateError('Invalid generator witness');
    }
    return level;
  }

  Level daily(DateTime date) {
    final key = date.year * 10000 + date.month * 100 + date.day;
    return generate(30, seed: key);
  }
}
