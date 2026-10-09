import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/game/generator.dart';
import 'package:bus_jam/game/model.dart';

void main() {
  final generator = LevelGenerator();

  test('every authored hard puzzle has a valid winning witness', () {
    for (var number = 1; number <= 30; number++) {
      final level = generator.generate(number);
      if (!level.hard) continue;
      var board = Board.initial(level);
      for (final lane in level.solution) {
        final move = GameEngine.release(level, board, lane);
        expect(move.accepted, isTrue, reason: 'level $number');
        board = move.board;
        board.validate(level);
      }
      expect(board.phase(level), GamePhase.won, reason: 'level $number');
    }
  });

  test('every campaign level can be solved from its starting position', () {
    for (var number = 1; number <= 30; number++) {
      final level = generator.generate(number);
      final initial = Board.initial(level);
      final route = GameEngine.solve(level, initial);
      expect(route, isNotNull, reason: 'level $number');
      expect(route, isNotEmpty, reason: 'level $number');
    }
  });

  test('procedural difficulty alternates pressure and recovery rounds', () {
    for (var number = 31; number <= 50; number++) {
      final level = generator.generate(number);
      if (number % 5 == 0) {
        expect(level.hard, isFalse, reason: 'recovery route $number');
      } else {
        expect(level.hard, isTrue, reason: 'pressure route $number');
      }
    }
  });

  test('procedural puzzles preserve solvability and deterministic seeds', () {
    for (final number in <int>[31, 32, 35, 40, 45, 50]) {
      final level = generator.generate(number);
      final replay = LevelGenerator().generate(number);
      expect(level.solution, replay.solution);
      expect(level.passengers, replay.passengers);
      expect(level.parkingTarget, replay.parkingTarget);
      var board = Board.initial(level);
      for (final lane in level.solution) {
        final move = GameEngine.release(level, board, lane);
        expect(move.accepted, isTrue, reason: 'level $number');
        board = move.board;
      }
      expect(board.phase(level), GamePhase.won, reason: 'level $number');
    }
  });
}
