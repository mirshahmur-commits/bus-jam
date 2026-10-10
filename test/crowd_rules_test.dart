import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/game/generator.dart';
import 'package:bus_jam/game/model.dart';
import 'package:bus_jam/game/progression.dart';

import 'fixtures.dart';

Board play(Level level, List<int> cells) {
  var board = Board.initial(level);
  for (final cell in cells) {
    final move = GameEngine.tap(level, board, cell);
    expect(move.accepted, true, reason: 'tap $cell');
    board = move.board;
    board.validate(level);
  }
  return board;
}

void main() {
  final level = trafficFixture();

  test('BR-01 only passengers with a clear path to the stop can move', () {
    final board = Board.initial(level);
    expect(board.reachable(level), {0, 1, 2, 3, 4, 5});
    expect(GameEngine.tap(level, board, 6).accepted, false);
    final opened = play(level, [0]);
    expect(opened.reachable(level), containsAll([1, 2, 3, 4, 5, 6]));
    expect(opened.reachable(level).contains(7), false);
  });

  test('BR-02 empty, out-of-range and finished taps are no-ops', () {
    final board = play(level, [0]);
    for (final cell in [-1, 0, 12, 99]) {
      final move = GameEngine.tap(level, board, cell);
      expect(move.accepted, false);
      expect(identical(move.board, board), true);
    }
    final won = play(level, level.solution);
    expect(won.phase(level), GamePhase.won);
    expect(GameEngine.tap(level, won, 0).accepted, false);
  });

  test('BR-03 a matching passenger boards; others take the next slot', () {
    final first = GameEngine.tap(level, Board.initial(level), 0);
    expect(first.toBus, false);
    expect(first.waitingSlot, 0);
    expect(first.board.waiting, [BusColor.blue]);
    final second = GameEngine.tap(level, first.board, 6);
    expect(second.toBus, true);
    expect(second.board.boarded, 1);
    expect(second.board.waiting, [BusColor.blue]);
  });

  test('BR-04 a full bus leaves and the next collects waiting passengers', () {
    final before = play(level, [0, 1, 3, 6, 7]);
    expect(before.waiting, [BusColor.blue, BusColor.blue, BusColor.gold]);
    final move = GameEngine.tap(level, before, 8);
    expect(move.departures, 1);
    expect(move.fromWaiting, [0, 1]);
    expect(move.board.busIndex, 1);
    expect(move.board.boarded, 2);
    expect(move.board.waiting, [BusColor.gold]);
  });

  test('BR-05 waiting passengers can fill and send away several buses', () {
    // Blue and gold wait while the coral bus is filled last.
    final failed = play(level, [0, 1, 2, 3, 4]);
    var b = GameEngine.continueWithSlot(level, failed);
    for (final cell in [6, 7]) {
      b = GameEngine.tap(level, b, cell).board;
    }
    final move = GameEngine.tap(level, b, 8);
    expect(move.departures, 2);
    expect(move.fromWaiting, [0, 1, 2, 3, 4]);
    expect(move.board.busIndex, 2);
    expect(move.board.boarded, 2);
    expect(move.board.waiting, isEmpty);
    move.board.validate(level);
  });

  test('BR-06 five full slots fail; one extra slot per attempt', () {
    final failed = play(level, trafficFailure);
    expect(failed.phase(level), GamePhase.failed);
    expect(GameEngine.tap(level, failed, 6).accepted, false);
    final more = GameEngine.continueWithSlot(level, failed);
    expect(more.slots, 6);
    expect(more.phase(level), GamePhase.playing);
    expect(identical(GameEngine.continueWithSlot(level, more), more), true);
    final fresh = Board.initial(level);
    expect(identical(GameEngine.continueWithSlot(level, fresh), fresh), true);
  });

  test('BR-07 the stored witness wins and its waiting score is exact', () {
    final won = play(level, level.solution);
    expect(won.phase(level), GamePhase.won);
    expect(won.remaining, 0);
    expect(GameEngine.waitingCost(level, level.solution), 3);
  });

  test('BR-08 walks are contiguous through open pavement to row 0', () {
    final board = play(level, [0, 6]);
    final path = board.walk(level, 7);
    expect(path.first, 7);
    expect(path.last < level.cols, true);
    for (int i = 1; i < path.length; i++) {
      expect(Board.neighbours(level, path[i - 1]), contains(path[i]));
      expect(board.people[path[i]], -1);
    }
  });

  test('BR-09 hidden passengers are revealed only once reachable', () {
    final hiddenLevel = Level(
      number: 9,
      seed: 9,
      rows: 2,
      cols: 3,
      cells: const [0, 0, 0, 1, 1, 1],
      buses: const [BusColor.coral, BusColor.blue],
      hidden: const {4},
    );
    final board = Board.initial(hiddenLevel);
    expect(board.reachable(hiddenLevel).contains(4), false);
    final open = GameEngine.tap(hiddenLevel, board, 1).board;
    expect(open.reachable(hiddenLevel).contains(4), true);
    expect(
      () => Level(
        number: 1,
        seed: 1,
        rows: 1,
        cols: 3,
        cells: const [0, 0, -1],
        buses: const [BusColor.coral],
        hidden: const {2},
      ),
      throwsFormatException,
    );
  });

  test('BR-10 levels reject seat and passenger mismatches', () {
    expect(
      () => Level(
        number: 1,
        seed: 1,
        rows: 1,
        cols: 3,
        cells: const [0, 0, 1],
        buses: const [BusColor.coral],
      ),
      throwsFormatException,
    );
    expect(
      () => Level(
        number: 1,
        seed: 1,
        rows: 2,
        cols: 3,
        cells: const [0, 0, 0],
        buses: const [BusColor.coral],
      ),
      throwsFormatException,
    );
  });

  test('BR-11 saves reject recoloured, invented or unsettled passengers', () {
    final board = play(level, [0, 6]);
    final json = board.toJson();
    expect(jsonEncode(Board.fromJson(json, level).toJson()), jsonEncode(json));
    final recoloured = Map<String, dynamic>.from(json)
      ..['people'] = (List<int>.from(json['people'] as List)..[1] = 2);
    expect(() => Board.fromJson(recoloured, level), throwsFormatException);
    final invented = Map<String, dynamic>.from(json)..['waiting'] = [1, 1];
    expect(() => Board.fromJson(invented, level), throwsFormatException);
    final unsettled = Map<String, dynamic>.from(json)
      ..['waiting'] = [1, 0]
      ..['boarded'] = 0;
    expect(() => Board.fromJson(unsettled, level), throwsFormatException);
    final slots = Map<String, dynamic>.from(json)..['slots'] = 7;
    expect(() => Board.fromJson(slots, level), throwsFormatException);
  });

  test('BR-12 hints are genuine routes and dead ends get none', () {
    final route = GameEngine.solve(level, Board.initial(level))!;
    expect(play(level, route).phase(level), GamePhase.won);
    expect(GameEngine.solve(level, play(level, trafficFailure)), isNull);
  });

  test('BR-13 scoring: stars for extra slot, hints and waiting target', () {
    final won = play(level, level.solution);
    final perfect = evaluateRoute(
      level,
      won,
      parkingCost: level.parkingTarget,
      usedHint: false,
    );
    expect((perfect.stars, perfect.score), (3, 2000));
    final hinted = evaluateRoute(
      level,
      won,
      parkingCost: level.parkingTarget,
      usedHint: true,
    );
    expect((hinted.stars, hinted.score), (2, 1850));
    final slow = evaluateRoute(
      level,
      won,
      parkingCost: level.parkingTarget + 3,
      usedHint: false,
    );
    expect((slow.stars, slow.score), (2, 1850));
    expect(
      () => evaluateRoute(
        level,
        Board.initial(level),
        parkingCost: 0,
        usedHint: false,
      ),
      throwsStateError,
    );
  });

  group('generator', () {
    final generator = LevelGenerator();

    test('GEN-01 deterministic, round-trips and replays its witness', () {
      for (int n = 1; n <= 120; n++) {
        final l = generator.generate(n);
        expect(
          jsonEncode(LevelGenerator().generate(n).toJson()),
          jsonEncode(l.toJson()),
        );
        expect(
          jsonEncode(Level.fromJson(l.toJson()).toJson()),
          jsonEncode(l.toJson()),
        );
        expect(play(l, l.solution).phase(l), GamePhase.won);
        expect(GameEngine.waitingCost(l, l.solution), l.parkingTarget);
        expect(l.hidden.every((i) => i >= l.cols), true);
      }
    });

    test('GEN-02 difficulty grows: bigger crowds, more colours, secrets', () {
      final first = generator.generate(1), later = generator.generate(40);
      expect(first.passengerCount, lessThan(later.passengerCount));
      expect(first.buses.toSet().length, lessThan(later.buses.toSet().length));
      for (int n = 1; n < 8; n++) {
        expect(generator.generate(n).hidden, isEmpty);
      }
      final secrets = [
        for (int n = 20; n < 40; n++) generator.generate(n).hidden.length,
      ];
      expect(secrets.where((h) => h > 0).length, greaterThan(15));
      final waits = [
        for (int n = 10; n < 60; n++) generator.generate(n).parkingTarget,
      ];
      expect(waits.where((w) => w > 0).length, greaterThan(30));
    });

    test('GEN-03 daily boards are deterministic and change by date', () {
      final a = generator.daily(DateTime.utc(2026, 10, 6));
      final b = generator.daily(DateTime.utc(2026, 10, 7));
      expect(
        jsonEncode(LevelGenerator().daily(DateTime.utc(2026, 10, 6)).toJson()),
        jsonEncode(a.toJson()),
      );
      expect(jsonEncode(a.toJson()) == jsonEncode(b.toJson()), false);
      expect(a.seed, 20261006);
    });
  });
}
