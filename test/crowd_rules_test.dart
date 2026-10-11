import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/game/generator.dart';
import 'package:bus_jam/game/model.dart';
import 'package:bus_jam/game/progression.dart';

import 'fixtures.dart';

Board play(Level level, List<int> lanes, {Board? from}) {
  var board = from ?? Board.initial(level);
  for (final lane in lanes) {
    final move = GameEngine.tap(level, board, lane);
    expect(move.accepted, true, reason: 'lane $lane');
    board = move.board;
    board.validate(level);
  }
  return board;
}

void main() {
  final level = trafficFixture();

  test('BR-01 a tap sends the front passenger; the lane steps forward', () {
    final board = Board.initial(level);
    expect(board.front(level, 0), BusColor.blue.index);
    final next = play(level, [0]);
    expect(next.taken, [1, 0, 0, 0]);
    expect(next.front(level, 0), BusColor.coral.index);
    expect(next.remaining(level), 11);
  });

  test('BR-02 empty, out-of-range and finished taps are no-ops', () {
    final wide = GameEngine.continueWithSlot(level, Board.initial(level));
    final emptied = play(level, [3, 3, 3], from: wide);
    for (final lane in [-1, 3, 4, 99]) {
      final move = GameEngine.tap(level, emptied, lane);
      expect(move.accepted, false);
      expect(identical(move.board, emptied), true);
    }
    final won = play(level, level.solution);
    expect(won.phase(level), GamePhase.won);
    expect(GameEngine.tap(level, won, 0).accepted, false);
  });

  test('BR-03 a matching passenger boards; others take the next slot', () {
    final first = GameEngine.tap(level, Board.initial(level), 0);
    expect(first.toBus, false);
    expect(first.waitingSlot, 0);
    expect(first.color, BusColor.blue);
    expect(first.board.waiting, [BusColor.blue]);
    final second = GameEngine.tap(level, first.board, 0);
    expect(second.toBus, true);
    expect(second.seat, 0);
    expect(second.board.boarded, 1);
    expect(second.board.waiting, [BusColor.blue]);
  });

  test('BR-04 a full bus leaves and the next seats waiting passengers', () {
    final before = play(level, [0, 0, 0, 1]);
    expect(before.waiting, [BusColor.blue, BusColor.blue]);
    final move = GameEngine.tap(level, before, 1);
    expect(move.departures, 1);
    expect(move.fromWaiting, [0, 1]);
    expect(move.board.busIndex, 1);
    expect(move.board.boarded, 2);
    expect(move.board.waiting, isEmpty);
  });

  test('BR-05 waiting passengers can fill and send away several buses', () {
    final failed = play(level, trafficFailure);
    final wide = GameEngine.continueWithSlot(level, failed);
    final b = play(level, [0, 0], from: wide);
    final move = GameEngine.tap(level, b, 1);
    expect(move.departures, 2);
    expect(move.fromWaiting, [0, 1, 2]);
    expect(move.board.busIndex, 2);
    expect(move.board.boarded, 0);
    expect(move.board.waiting, [BusColor.mint, BusColor.mint]);
    move.board.validate(level);
  });

  test('BR-06 five full slots fail; one extra slot per attempt', () {
    final failed = play(level, trafficFailure);
    expect(failed.phase(level), GamePhase.failed);
    expect(GameEngine.tap(level, failed, 0).accepted, false);
    final more = GameEngine.continueWithSlot(level, failed);
    expect(more.slots, 6);
    expect(more.phase(level), GamePhase.playing);
    expect(identical(GameEngine.continueWithSlot(level, more), more), true);
    expect(
      play(level, trafficRecovery, from: more).phase(level),
      GamePhase.won,
    );
    // The extra slot can also be bought before the stop jams.
    final early = GameEngine.continueWithSlot(level, Board.initial(level));
    expect((early.slots, early.continued), (6, true));
  });

  test('BR-07 the stored witness wins and its waiting score is exact', () {
    final won = play(level, level.solution);
    expect(won.phase(level), GamePhase.won);
    expect(won.remaining(level), 0);
    expect(GameEngine.waitingCost(level, level.solution), 5);
  });

  test('BR-08 hidden passengers are revealed at the front of the lane', () {
    final hiddenLevel = Level(
      number: 9,
      seed: 9,
      lanes: const [
        [0, 1, 0],
        [0, 1, 1],
      ],
      buses: const [BusColor.coral, BusColor.blue],
      hidden: {Level.key(0, 1)},
    );
    expect(hiddenLevel.isHidden(0, 1), true);
    expect(hiddenLevel.isHidden(0, 0), false);
    for (final bad in [Level.key(0, 0), Level.key(0, 3), Level.key(5, 1)]) {
      expect(
        () => Level(
          number: 1,
          seed: 1,
          lanes: const [
            [0, 0, 0],
          ],
          buses: const [BusColor.coral],
          hidden: {bad},
        ),
        throwsFormatException,
      );
    }
  });

  test('BR-09 levels reject seat and passenger mismatches', () {
    expect(
      () => Level(
        number: 1,
        seed: 1,
        lanes: const [
          [0, 0, 1],
        ],
        buses: const [BusColor.coral],
      ),
      throwsFormatException,
    );
    expect(
      () => Level(
        number: 1,
        seed: 1,
        lanes: const [[]],
        buses: const [BusColor.coral],
      ),
      throwsFormatException,
    );
  });

  test('BR-10 saves reject invented, overdrawn or unsettled passengers', () {
    final board = play(level, [0, 0]);
    final json = board.toJson();
    expect(jsonEncode(Board.fromJson(json, level).toJson()), jsonEncode(json));
    final invented = Map<String, dynamic>.from(json)..['waiting'] = [1, 1];
    expect(() => Board.fromJson(invented, level), throwsFormatException);
    final overdrawn = Map<String, dynamic>.from(json)..['taken'] = [4, 0, 0, 0];
    expect(() => Board.fromJson(overdrawn, level), throwsFormatException);
    final unsettled = Map<String, dynamic>.from(json)
      ..['waiting'] = [1, 0]
      ..['boarded'] = 0;
    expect(() => Board.fromJson(unsettled, level), throwsFormatException);
    final slots = Map<String, dynamic>.from(json)..['slots'] = 7;
    expect(() => Board.fromJson(slots, level), throwsFormatException);
  });

  test('BR-11 hints are genuine routes and dead ends get none', () {
    final route = GameEngine.solve(level, Board.initial(level))!;
    expect(play(level, route).phase(level), GamePhase.won);
    expect(GameEngine.solve(level, play(level, trafficFailure)), isNull);
  });

  test('BR-12 scoring: stars for extra slot, hints and waiting target', () {
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
      }
    });

    test('GEN-02 difficulty grows: longer lines, more colours, secrets', () {
      final first = generator.generate(1), later = generator.generate(40);
      expect(first.passengerCount, lessThan(later.passengerCount));
      expect(first.buses.toSet().length, lessThan(later.buses.toSet().length));
      // Later crowds stream past the screen edge for a constant flow.
      expect(later.lanes.every((l) => l.length >= 10), true);
      for (int n = 1; n < 8; n++) {
        expect(generator.generate(n).hidden, isEmpty);
      }
      final secrets = [
        for (int n = 20; n < 40; n++) generator.generate(n).hidden.length,
      ];
      expect(secrets.every((h) => h > 0), true);
      final waits = [
        for (int n = 10; n < 60; n++) generator.generate(n).parkingTarget,
      ];
      expect(waits.where((w) => w > 0).length, greaterThan(40));
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
