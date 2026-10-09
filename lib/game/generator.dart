import 'dart:math';

import 'campaign.dart';
import 'engine.dart';
import 'model.dart';

class LevelGenerator {
  static const version = 2;
  final _cache = <String, Level>{};

  Level generate(int number, {int? seed}) {
    if (number < 1) throw ArgumentError.value(number);
    final actualSeed = seed ?? number * 7919 + 104729;
    final key = '$number/$actualSeed';
    if (_cache.containsKey(key)) return _cache[key]!;
    final rng = Random(actualSeed);
    final colors = BusColor.values.toList();
    final order = [0, 1, 2];
    RoutePlan plan;
    RoutePlan? extension;
    if (number <= campaign.length) {
      plan = campaign[number - 1];
      // The authored campaign is fixed. Daily permutations share a UTC seed.
      if (seed != null) {
        colors.shuffle(rng);
        order.shuffle(rng);
      }
    } else {
      final easy = number % 5 == 0;
      // Keep every fifth level as a short recovery round. Other
      // procedural levels reuse the campaign's proven pressure puzzles.
      // Their colour/lane permutations keep them replayable and solvable.
      final indices = easy
          ? [5, 9, 14, 19, 24]
          : [3, 7, 10, 12, 17, 21, 23, 26, 28, 29];
      // Sample several proven templates and favour real decision pressure.
      // The solver measures choices that can lead to a dead end.
      var bestIndex = indices[rng.nextInt(indices.length)];
      if (!easy) {
        var bestScore = -1;
        for (final index in indices) {
          final candidate = campaign[index];
          final score = candidate.hard ? 2 : 0;
          if (score > bestScore || (score == bestScore && rng.nextBool())) {
            bestScore = score;
            bestIndex = index;
          }
        }
      }
      plan = campaign[bestIndex];
      colors.shuffle(rng);
      order.shuffle(rng);
      if (!easy && number.isEven) {
        // An additional connected depot creates longer planning chains.
        // The exact solver below validates the combined route.
        const extensions = [6, 7, 10, 12, 13];
        extension = campaign[extensions[rng.nextInt(extensions.length)]];
      }
    }
    final lanes = List.generate(3, (_) => <Bus>[]);
    final passengers = <BusColor>[];
    var id = 0;
    void add(RoutePlan part) {
      for (int lane = 0; lane < 3; lane++) {
        for (final token
            in part.lanes[lane].split(' ').where((v) => v.isNotEmpty)) {
          lanes[order[lane]].add(
            Bus(
              id++,
              colors[token.codeUnitAt(0) - 97],
              capacity: int.parse(token.substring(1)),
            ),
          );
        }
      }
      for (final token in part.queue.split(' ')) {
        passengers.addAll(
          List.filled(
            int.parse(token.substring(1)),
            colors[token.codeUnitAt(0) - 97],
          ),
        );
      }
    }

    add(plan);
    if (extension != null) add(extension);
    final draft = Level(
      number: number,
      seed: actualSeed,
      lanes: lanes,
      passengers: passengers,
      generatorVersion: version,
    );
    final analysis = GameEngine.analyze(draft);
    final level = Level(
      number: number,
      seed: actualSeed,
      lanes: lanes,
      passengers: passengers,
      solution: analysis.route,
      generatorVersion: version,
      title: number <= 30 ? plan.title : '${plan.title} ${number - 30}',
      lesson: plan.lesson,
      parkingTarget: analysis.parkingCost,
      hard: plan.hard || extension?.hard == true,
    );
    var board = Board.initial(level);
    for (final lane in level.solution) {
      final move = GameEngine.release(level, board, lane);
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
    return generate(30, seed: utc.year * 10000 + utc.month * 100 + utc.day);
  }
}
