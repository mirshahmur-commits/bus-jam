import 'dart:convert';
import 'dart:io';

import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/game/generator.dart';
import 'package:bus_jam/game/model.dart';

void main(List<String> args) {
  final count = args.isEmpty ? 10000 : int.parse(args.first);
  final generator = LevelGenerator();
  var checks = 0, moves = 0, solverChecks = 0;
  final watch = Stopwatch()..start();
  for (int n = 1; n <= count; n++) {
    final level = generator.generate(n);
    final clone = Level.fromJson(
      jsonDecode(jsonEncode(level.toJson())) as Map<String, dynamic>,
    );
    if (jsonEncode(clone.toJson()) != jsonEncode(level.toJson())) {
      throw StateError('Roundtrip $n');
    }
    if (jsonEncode(generator.generate(n).toJson()) !=
        jsonEncode(level.toJson())) {
      throw StateError('Non-determinism $n');
    }
    var board = Board.initial(level);
    for (final lane in level.solution) {
      final result = GameEngine.release(level, board, lane);
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
    if (board.phase(level) != GamePhase.won) {
      throw StateError('Not won $n');
    }
    if (n <= 300) {
      final route = GameEngine.solve(level, Board.initial(level));
      if (route == null) {
        throw StateError('Solver missed level $n');
      }
      var solved = Board.initial(level);
      for (final lane in route) {
        solved = GameEngine.release(level, solved, lane).board;
      }
      if (solved.phase(level) != GamePhase.won) {
        throw StateError('Bad hint $n');
      }
      solverChecks++;
    }
    checks++;
  }
  final result = {
    'status': 'Passed',
    'levels': checks,
    'witnessMoves': moves,
    'independentSolverLevels': solverChecks,
    'generatorVersion': LevelGenerator.version,
    'elapsedMs': watch.elapsedMilliseconds,
    'utc': DateTime.now().toUtc().toIso8601String(),
  };
  Directory('docs/evidence').createSync(recursive: true);
  File(
    'docs/evidence/generator.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln(jsonEncode(result));
}
