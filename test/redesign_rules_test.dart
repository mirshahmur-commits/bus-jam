import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/campaign.dart';
import 'package:bus_jam/game/controller.dart';
import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/game/generator.dart';
import 'package:bus_jam/game/legacy_generator.dart';
import 'package:bus_jam/game/model.dart';
import 'package:bus_jam/game/progression.dart';
import 'package:bus_jam/platform/leaderboards.dart';
import 'package:bus_jam/platform/progress_store.dart';

class FakeRankings extends OfflineLeaderboards {
  final submitted = <DailyScore>[];
  DailyScore? opened;
  @override
  bool get enabled => true;
  @override
  Future<bool> submit(DailyScore score) async {
    submitted.add(score);
    return true;
  }

  @override
  Future<bool> open(DailyScore? score) async {
    opened = score;
    return true;
  }
}

void finish(GameController c) {
  for (final lane in GameEngine.solve(c.level, c.board)!) {
    c.release(lane);
  }
}

void main() {
  test(
    'Campaign contains 30 distinct lessons and genuine planning decisions',
    () {
      expect(campaign.length, 30);
      expect(campaign.map((p) => p.title).toSet().length, 30);
      final g = LevelGenerator();
      var decisions = 0;
      for (int n = 1; n <= 30; n++) {
        final level = g.generate(n);
        final analysis = GameEngine.analyze(level);
        expect(level.parkingTarget, analysis.parkingCost);
        expect(analysis.route, level.solution);
        if (n >= 4 && analysis.decisions > 0) decisions++;
        if (level.hard) {
          expect(
            analysis.decisions,
            greaterThan(0),
            reason: 'Challenge $n needs a meaningful risky choice',
          );
        }
        if (n < 16) {
          expect(
            level.lanes.expand((l) => l).every((b) => b.capacity == 3),
            true,
          );
        }
      }
      expect(decisions, greaterThanOrEqualTo(23));
      expect(
        g
            .generate(16)
            .lanes
            .expand((l) => l)
            .map((b) => b.capacity)
            .toSet()
            .length,
        greaterThan(1),
      );
    },
  );

  test(
    'Route 4 requires saving room for two blocking buses and the hidden bus',
    () {
      final level = LevelGenerator().generate(4);
      var wrong = GameEngine.release(level, Board.initial(level), 1).board;
      wrong = GameEngine.release(level, wrong, 0).board;
      wrong = GameEngine.release(level, wrong, 0).board;
      expect(wrong.phase(level), GamePhase.failed);
      var correct = Board.initial(level);
      for (final lane in [0, 0, 0, 1]) {
        correct = GameEngine.release(level, correct, lane).board;
      }
      expect(correct.phase(level), GamePhase.won);
    },
  );

  test('Parking score distinguishes equal-length winning solutions', () async {
    final best = GameController(store: MemoryProgressStore());
    await best.load();
    best.release(0);
    best.release(1);
    final worse = GameController(store: MemoryProgressStore());
    await worse.load();
    worse.release(1);
    worse.release(0);
    expect(best.board.moves, worse.board.moves);
    expect(best.lastResult!.stars, 3);
    expect(worse.lastResult!.stars, 2);
    expect(best.lastResult!.score, greaterThan(worse.lastResult!.score));
    expect(best.lastResult!.parkingCost, 0);
    expect(worse.lastResult!.parkingCost, 1);
    expect(
      () => evaluateRoute(
        best.level,
        Board.initial(best.level),
        parkingCost: 0,
        usedHint: false,
      ),
      throwsStateError,
    );
  });

  test(
    'Best score and stars survive worse replays without farming coins',
    () async {
      final store = MemoryProgressStore();
      final c = GameController(store: store);
      await c.load();
      finish(c);
      final best = c.routeRecord(1)!;
      c.openLevel(1);
      c.release(1);
      c.release(0);
      expect(c.routeRecord(1)!.score, best.score);
      expect(c.routeRecord(1)!.stars, best.stars);
      expect(c.lastResult!.personalBest, false);
      expect(c.lastResult!.reward, 0);
      expect(c.coins, 175);
      await c.save();
      final r = GameController(store: store);
      await r.load();
      expect(r.totalStars, 3);
      expect(r.lastResult!.score, c.lastResult!.score);
      expect(r.board.phase(r.level), GamePhase.won);
    },
  );

  test(
    'One free undo per attempt; subsequent undo costs coins and restores pressure',
    () async {
      final c = GameController(store: MemoryProgressStore());
      await c.load();
      c.release(1);
      expect(c.parkingCost, 1);
      expect(c.cost(Assist.undo), 0);
      expect(c.spend(Assist.undo), true);
      expect(c.coins, 150);
      expect(c.parkingCost, 0);
      expect(c.cost(Assist.undo), 20);
      c.release(1);
      expect(c.spend(Assist.undo), true);
      expect(c.coins, 130);
      c.restart();
      expect(c.cost(Assist.undo), 0);
    },
  );

  test(
    'Hint and extra space change medals; free undo does not remove a star',
    () async {
      final c = GameController(store: MemoryProgressStore());
      await c.load();
      c.spend(Assist.hint);
      finish(c);
      expect(c.lastResult!.stars, 2);
      expect(c.lastResult!.ranked, false);
      c.openLevel(1);
      c.release(1);
      c.spend(Assist.undo);
      finish(c);
      expect(c.lastResult!.stars, 3);
      expect(c.lastResult!.ranked, false);
    },
  );

  test(
    'Collection debit is atomic; unknown, duplicate, unaffordable and unowned equip fail',
    () async {
      final c = GameController(store: MemoryProgressStore());
      await c.load();
      expect(c.buyCosmetic('metro'), false);
      expect(c.equipCosmetic('metro'), false);
      expect(c.buyCosmetic('unknown'), false);
      expect(c.coins, 150);
      c.coins = 800;
      expect(c.buyCosmetic('metro'), true);
      expect(c.coins, 500);
      expect(c.selectedBus, 'metro');
      expect(c.buyCosmetic('metro'), false);
      expect(c.coins, 500);
      expect(c.buyCosmetic('terminal-coast'), true);
      expect(c.coins, 0);
      expect(c.selectedTerminal, 'terminal-coast');
      expect(c.equipCosmetic('classic'), true);
      expect(c.coins, 0);
      expect(c.selectedBus, 'classic');
      expect(
        cosmetics.map((c) => c.productId).toSet().length,
        cosmetics.length,
      );
    },
  );

  test(
    'Owned collection, equipped styles and free undo state survive relaunch',
    () async {
      final store = MemoryProgressStore();
      final c = GameController(store: store);
      await c.load();
      c.coins = 1200;
      c.buyCosmetic('retro');
      c.buyCosmetic('terminal-garden');
      c.release(1);
      c.spend(Assist.undo);
      await c.save();
      final r = GameController(store: store);
      await r.load();
      expect(r.selectedBus, 'retro');
      expect(r.selectedTerminal, 'terminal-garden');
      expect(r.coins, 0);
      expect(r.ownedCosmetics, containsAll(['retro', 'terminal-garden']));
      expect(r.cost(Assist.undo), 20);
    },
  );

  test(
    'Version 1 progress migrates with its exact active board, history and money',
    () async {
      final store = MemoryProgressStore();
      final old = GameController(store: store);
      await old.load();
      old.level = LegacyLevelGenerator().generate(18);
      old.unlocked = 18;
      old.restart();
      old.release(old.level.solution.first);
      old.coins = 777;
      final json = jsonDecode(old.snapshot()) as Map<String, dynamic>;
      json['schema'] = 1;
      json.remove('records');
      json.remove('rankedDailyScores');
      json.remove('ownedCosmetics');
      json.remove('selectedBus');
      json.remove('selectedTerminal');
      (json['session'] as Map).remove('run');
      final expected = jsonEncode(old.board.toJson());
      await store.write(jsonEncode(json));
      final upgraded = GameController(store: store);
      await upgraded.load();
      expect(upgraded.level.generatorVersion, 1);
      expect(jsonEncode(upgraded.board.toJson()), expected);
      expect(upgraded.coins, 777);
      expect(upgraded.unlocked, 18);
      expect(upgraded.history.length, old.history.length);
      expect(upgraded.records, isEmpty);
      await upgraded.save();
      expect((jsonDecode(store.value!) as Map)['schema'], 2);
      upgraded.openLevel(18);
      expect(upgraded.level.generatorVersion, 2);
    },
  );

  test(
    'Daily restores campaign run metadata, including free undo and hint use',
    () async {
      final c = GameController(store: MemoryProgressStore());
      await c.load();
      c.release(1);
      c.spend(Assist.undo);
      c.spend(Assist.hint);
      final snapshot = jsonEncode(c.board.toJson());
      c.openDaily();
      expect(c.usedHint, false);
      expect(c.freeUndoUsed, false);
      c.returnToCampaign();
      expect(c.usedHint, true);
      expect(c.freeUndoUsed, true);
      expect(jsonEncode(c.board.toJson()), snapshot);
    },
  );

  test(
    'Daily competition submits only clean current-day results and survives offline play',
    () async {
      var day = DateTime.utc(2026, 10, 8);
      final rankings = FakeRankings();
      final c = GameController(
        store: MemoryProgressStore(),
        clock: () => day,
        leaderboards: rankings,
      );
      await c.load();
      c.openDaily();
      c.spend(Assist.hint);
      finish(c);
      await Future<void>.delayed(Duration.zero);
      expect(rankings.submitted, isEmpty);
      c.openDaily();
      finish(c);
      await Future<void>.delayed(Duration.zero);
      expect(rankings.submitted.single.seed, 20261008);
      await c.showDailyRanking();
      expect(rankings.opened!.score, c.rankedDailyScores['20261008']);
      c.openDaily();
      day = DateTime.utc(2026, 10, 9);
      finish(c);
      await Future<void>.delayed(Duration.zero);
      expect(rankings.submitted.length, 1);
      expect(c.rankedDailyScores.containsKey('20261009'), false);
    },
  );

  test(
    'Stale gesture identity cannot release a different bus after a rapid move',
    () async {
      final c = GameController(store: MemoryProgressStore());
      await c.load();
      c.unlocked = 4;
      c.openLevel(4);
      final id = c.board.lanes[0].first.id;
      expect(c.release(0, expectedBusId: id).accepted, true);
      expect(c.release(0, expectedBusId: id).accepted, false);
      expect(c.board.moves, 1);
      expect(
        c.release(0, expectedBusId: c.board.lanes[0].first.id).accepted,
        true,
      );
    },
  );

  test('Equal-colour parked bus order remains part of solver state', () {
    final level = Level(
      number: 1,
      seed: 1,
      lanes: [
        [const Bus(0, BusColor.blue, capacity: 2)],
        [const Bus(1, BusColor.blue, capacity: 4)],
      ],
      passengers: List.filled(6, BusColor.blue),
    );
    final one = Board(
      lanes: const [[], []],
      parked: [level.lanes[0].first, level.lanes[1].first],
      cursor: 0,
      departed: 0,
      moves: 2,
      slots: 3,
    );
    final two = Board(
      lanes: const [[], []],
      parked: one.parked.reversed.toList(),
      cursor: 0,
      departed: 0,
      moves: 2,
      slots: 3,
    );
    expect(one.searchKey, isNot(two.searchKey));
  });
}
