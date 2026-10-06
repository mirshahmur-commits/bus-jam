import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/game/generator.dart';
import 'package:bus_jam/game/model.dart';

import 'fixtures.dart';

void main() {
  test('BR-01 only lane front releases; source state stays immutable', () {
    final l = trafficFixture(), b = Board.initial(trafficFixture());
    final r = GameEngine.release(l, b, 0);
    expect(r.accepted, true);
    expect(r.board.parked.single.id, 0);
    expect(r.board.lanes[0].first.id, 1);
    expect(b.lanes[0].first.id, 0);
    expect(b.moves, 0);
    expect(b.parked, isEmpty);
    expect(() => b.lanes[0].clear(), throwsUnsupportedError);
  });
  test('BR-02 mismatching bus waits; no passenger skips queue', () {
    final l = trafficFixture(),
        r = GameEngine.release(
          trafficFixture(),
          Board.initial(trafficFixture()),
          0,
        );
    expect(r.board.cursor, 0);
    expect(r.boarding, isEmpty);
    expect(r.board.parked.first.color, BusColor.blue);
    r.board.validate(l);
  });
  test('BR-03 exact capacity boards and departs; frees parking', () {
    final l = trafficFixture(),
        r = GameEngine.release(
          trafficFixture(),
          Board.initial(trafficFixture()),
          1,
        );
    expect(r.board.cursor, 3);
    expect(r.board.departed, 1);
    expect(r.departures.single.boarded, 3);
    expect(r.board.parked, isEmpty);
    expect(r.boarding.map((x) => x.passenger), [0, 1, 2]);
    r.board.validate(l);
  });
  test(
    'BR-04 multiple parked buses board automatically when queue unblocks',
    () {
      final l = trafficFixture();
      var b = Board.initial(l);
      b = GameEngine.release(l, b, 0).board;
      b = GameEngine.release(l, b, 0).board;
      final r = GameEngine.release(l, b, 1);
      expect(r.board.cursor, 9);
      expect(r.departures.length, 3);
      expect(r.board.parked, isEmpty);
    },
  );
  test(
    'BR-05 all slots blocked triggers fail; failed board rejects release',
    () {
      final l = trafficFixture();
      var b = Board.initial(l);
      for (int i = 0; i < 3; i++) {
        b = GameEngine.release(l, b, 0).board;
      }
      expect(b.phase(l), GamePhase.failed);
      expect(b.cursor, 0);
      expect(b.parked.length, 3);
      expect(GameEngine.release(l, b, 1).accepted, false);
    },
  );
  test('BR-06 one continue adds a slot and solves a real failed state', () {
    final l = trafficFixture();
    var b = Board.initial(l);
    for (int i = 0; i < 3; i++) {
      b = GameEngine.release(l, b, 0).board;
    }
    b = GameEngine.continueWithSlot(l, b);
    expect(b.slots, 4);
    expect(b.continued, true);
    expect(b.phase(l), GamePhase.playing);
    expect(GameEngine.continueWithSlot(l, b), same(b));
    b = GameEngine.release(l, b, 0).board;
    expect(b.cursor, 12);
    b = GameEngine.release(l, b, 1).board;
    expect(b.phase(l), GamePhase.won);
    b.validate(l);
  });
  test(
    'BR-07 victory requires every passenger and bus; won state is terminal',
    () {
      final l = trafficFixture();
      var b = Board.initial(l);
      for (final lane in l.solution) {
        b = GameEngine.release(l, b, lane).board;
      }
      expect(b.phase(l), GamePhase.won);
      expect(b.departed, 5);
      expect(b.cursor, 15);
      expect(GameEngine.release(l, b, 0).accepted, false);
      expect(GameEngine.continueWithSlot(l, b), same(b));
    },
  );
  test('BR-08 invalid lanes and empty lanes never mutate', () {
    final l = trafficFixture();
    var b = Board.initial(l);
    for (final n in [-1, 2, 999]) {
      expect(GameEngine.release(l, b, n).board, same(b));
    }
    b = GameEngine.release(l, b, 1).board;
    expect(GameEngine.release(l, b, 1).accepted, false);
  });
  test('BR-09 hint solves current board and detects dead ends', () {
    final l = trafficFixture();
    final initial = GameEngine.solve(l, Board.initial(l));
    expect(initial, isNotNull);
    var b = Board.initial(l);
    for (int i = 0; i < 3; i++) {
      b = GameEngine.release(l, b, 0).board;
    }
    expect(GameEngine.solve(l, b), isNull);
    expect(GameEngine.solve(l, Board.initial(l), maxStates: 0), isNull);
  });
  test('BR-10 mixed passenger colors fill partially before departure', () {
    final l = Level(
      number: 1,
      seed: 1,
      lanes: [
        [const Bus(0, BusColor.blue)],
        [const Bus(1, BusColor.coral)],
      ],
      passengers: [
        BusColor.blue,
        BusColor.coral,
        BusColor.blue,
        BusColor.coral,
        BusColor.blue,
        BusColor.coral,
      ],
    );
    final first = GameEngine.release(l, Board.initial(l), 0);
    expect(first.board.cursor, 1);
    expect(first.board.parked.single.boarded, 1);
    final last = GameEngine.release(l, first.board, 1);
    expect(last.board.phase(l), GamePhase.won);
    expect(last.departures.length, 2);
  });
  test('BR-11 seats and passenger totals reject malformed content', () {
    expect(
      () => Level(
        number: 1,
        seed: 1,
        lanes: [
          [const Bus(0, BusColor.blue)],
        ],
        passengers: [BusColor.coral],
      ),
      throwsFormatException,
    );
    expect(
      () => Level(
        number: 1,
        seed: 1,
        lanes: [
          [const Bus(0, BusColor.blue), const Bus(0, BusColor.blue)],
        ],
        passengers: List.filled(6, BusColor.blue),
      ),
      throwsFormatException,
    );
  });
  test(
    'BR-12 saves reject duplicate buses, reordered lanes and broken conservation',
    () {
      final l = trafficFixture(), b = Board.initial(trafficFixture());
      for (final change in ['cursor', 'moves', 'slots', 'lanes']) {
        final j = jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>;
        if (change == 'lanes') {
          (j['lanes'][0] as List).removeAt(1);
        } else {
          j[change] = (j[change] as int) + 1;
        }
        expect(
          () => Board.fromJson(j, l),
          throwsFormatException,
          reason: change,
        );
      }
    },
  );
  test(
    'BR-13 deterministic generator + witness + roundtrip across 1000 levels',
    () {
      for (int n = 1; n <= 1000; n++) {
        final l = LevelGenerator().generate(n);
        expect(
          jsonEncode(LevelGenerator().generate(n).toJson()),
          jsonEncode(l.toJson()),
        );
        var b = Board.initial(l);
        for (final lane in l.solution) {
          final r = GameEngine.release(l, b, lane);
          expect(r.accepted, true);
          b = r.board;
          b.validate(l);
        }
        expect(b.phase(l), GamePhase.won);
        expect(Level.fromJson(l.toJson()).seed, l.seed);
      }
    },
  );
  test('BR-14 random legal play conserves every seat and passenger', () {
    final rng = Random(91);
    for (int n = 1; n <= 200; n++) {
      final l = LevelGenerator().generate(n);
      var b = Board.initial(l);
      for (int step = 0; step < 60 && b.phase(l) == GamePhase.playing; step++) {
        final choices = [
          for (int i = 0; i < b.lanes.length; i++)
            if (b.lanes[i].isNotEmpty) i,
        ];
        b = GameEngine.release(
          l,
          b,
          choices[rng.nextInt(choices.length)],
        ).board;
        b.validate(l);
      }
      expect(b.phase(l), isNot(GamePhase.playing));
    }
  });
  test('BR-15 daily is stable on same date and changes next day', () {
    final g = LevelGenerator();
    expect(
      g.daily(DateTime(2026, 10, 6, 8)).seed,
      g.daily(DateTime(2026, 10, 6, 23)).seed,
    );
    expect(
      g.daily(DateTime(2026, 10, 6)).seed,
      isNot(g.daily(DateTime(2026, 10, 7)).seed),
    );
  });
}
