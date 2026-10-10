import 'dart:convert';
import 'dart:io';

import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/game/generator.dart';
import 'package:bus_jam/game/model.dart';

void main(List<String> args) {
  final count = args.isEmpty ? 10000 : int.parse(args.first);
  final generator = LevelGenerator();
  var checks = 0, moves = 0, solverChecks = 0, shuffled = 0;
  final watch = Stopwatch()..start();
  for (int n = 1; n <= count; n++) {
    final level = generator.generate(n);
    final clone = Level.fromJson(
      jsonDecode(jsonEncode(level.toJson())) as Map<String, dynamic>,
    );
    if (jsonEncode(clone.toJson()) != jsonEncode(level.toJson())) {
      throw StateError('Roundtrip $n');
    }
    if (jsonEncode(LevelGenerator().generate(n).toJson()) !=
        jsonEncode(level.toJson())) {
      throw StateError('Non-determinism $n');
    }
    var board = Board.initial(level);
    for (final lane in level.solution) {
      final result = GameEngine.tap(level, board, lane);
      if (!result.accepted) {
        throw StateError('Blocked witness $n');
      }
      board = result.board;
      board.validate(level);
      Board.fromJson(
        jsonDecode(jsonEncode(board.toJson())) as Map<String, dynamic>,
        level,
      );
      moves++;
    }
    if (GameEngine.waitingCost(level, level.solution) != level.parkingTarget) {
      throw StateError('Incorrect waiting target $n');
    }
    if (level.parkingTarget > 0) shuffled++;
    if (board.phase(level) != GamePhase.won) {
      throw StateError('Not won $n');
    }
    if (n <= 300) {
      final route = GameEngine.solve(level, Board.initial(level));
      if (route == null) {
        throw StateError('Solver missed a route $n');
      }
      var solved = Board.initial(level);
      for (final lane in route) {
        solved = GameEngine.tap(level, solved, lane).board;
      }
      if (solved.phase(level) != GamePhase.won) {
        throw StateError('Bad hint $n');
      }
      solverChecks++;
    }
    checks++;
  }
  final daily = generator.daily(DateTime.utc(2026, 1, 1));
  if (daily.solution.isEmpty) throw StateError('Empty daily');
  final evidence = {
    'status': 'Passed',
    'generatorVersion': LevelGenerator.version,
    'levels': checks,
    'witnessMoves': moves,
    'levelsNeedingWaitingSlots': shuffled,
    'independentSolverLevels': solverChecks,
    'elapsedMs': watch.elapsedMilliseconds,
  };
  stdout.writeln(jsonEncode(evidence));
  File(
    'docs/evidence/generator.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(evidence));
}
