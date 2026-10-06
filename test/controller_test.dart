import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/controller.dart';
import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/game/model.dart';
import 'package:bus_jam/platform/analytics.dart';
import 'package:bus_jam/platform/monetization.dart';
import 'package:bus_jam/platform/progress_store.dart';

import 'fixtures.dart';

class FakeAds extends OfflineAds {
  AdOutcome outcome = AdOutcome.unavailable;
  int calls = 0;
  Completer<AdOutcome>? pending;
  @override
  Future<AdOutcome> rewarded() {
    calls++;
    return pending?.future ?? Future.value(outcome);
  }
}

class FakePurchases extends OfflinePurchases {
  PurchaseOutcome outcome = PurchaseOutcome.unavailable;
  bool? restored;
  @override
  Future<PurchaseOutcome> buyRemoveAds() async => outcome;
  @override
  Future<bool?> restore() async => restored;
}

GameController create({
  ProgressStore? store,
  FakeAds? ads,
  FakePurchases? purchases,
  LocalAnalytics? analytics,
  DateTime Function()? clock,
}) => GameController(
  store: store ?? MemoryProgressStore(),
  ads: ads,
  purchases: purchases,
  analytics: analytics,
  clock: clock,
);
void traffic(GameController c) {
  c.level = trafficFixture();
  c.unlocked = 12;
  c.board = Board.initial(c.level);
  c.history = [];
}

void win(GameController c) {
  final solution = GameEngine.solve(c.level, c.board)!;
  for (final lane in solution) {
    c.release(lane);
  }
}

void main() {
  test('BR-16 first launch starts route 1 with 150 coins', () async {
    final c = create();
    await c.load();
    expect(c.unlocked, 1);
    expect(c.coins, 150);
    expect(c.onboarded, false);
    expect(c.board.moves, 0);
  });
  test(
    'BR-17 first completion awards exactly 25 coins, replay cannot farm',
    () async {
      final c = create();
      await c.load();
      win(c);
      expect(c.coins, 175);
      expect(c.unlocked, 2);
      expect(c.release(0).accepted, false);
      c.openLevel(1);
      win(c);
      expect(c.coins, 175);
      expect(c.unlocked, 2);
    },
  );
  test('BR-18 next only after victory; locked selection ignored', () async {
    final c = create();
    await c.load();
    await c.next();
    expect(c.level.number, 1);
    c.openLevel(2);
    expect(c.level.number, 1);
    win(c);
    await c.next();
    expect(c.level.number, 2);
    expect(c.board.moves, 0);
  });
  test('BR-19 genuine hint costs 25 without moving a bus', () async {
    final c = create();
    await c.load();
    expect(c.spend(Assist.hint), true);
    expect(c.coins, 125);
    expect(c.hintLane, isNotNull);
    expect(c.board.moves, 0);
  });
  test('BR-20 insufficient coins leaves state untouched', () async {
    final c = create();
    await c.load();
    c.coins = 0;
    expect(c.spend(Assist.hint), false);
    expect(c.hintLane, isNull);
  });
  test('BR-21 undo rolls back passengers, bus and moves exactly', () async {
    final c = create();
    await c.load();
    traffic(c);
    final original = c.board.toJson();
    c.release(1);
    expect(c.board.cursor, 3);
    expect(c.spend(Assist.undo), true);
    expect(jsonEncode(c.board.toJson()), jsonEncode(original));
    expect(c.coins, 130);
    expect(c.spend(Assist.undo), false);
  });
  test('BR-22 restart preserves currency and deterministic board', () async {
    final c = create();
    await c.load();
    traffic(c);
    c.release(0);
    final seed = c.level.seed;
    c.restart();
    expect(c.level.seed, seed);
    expect(c.board.moves, 0);
    expect(c.history, isEmpty);
    expect(c.coins, 150);
    expect(c.attempts, 2);
  });
  test('BR-23 extra slot once per attempt; undo retains entitlement', () async {
    final c = create();
    await c.load();
    traffic(c);
    for (int i = 0; i < 3; i++) {
      c.release(0);
    }
    expect(c.spend(Assist.extraSlot), true);
    expect(c.board.slots, 4);
    expect(c.coins, 100);
    expect(c.spend(Assist.extraSlot), false);
    expect(c.spend(Assist.undo), true);
    expect(c.board.slots, 4);
    expect(c.board.continued, true);
    c.restart();
    expect(c.board.slots, 3);
    expect(c.board.continued, false);
  });
  for (final outcome in [
    AdOutcome.dismissed,
    AdOutcome.unavailable,
    AdOutcome.error,
  ]) {
    test('BR-24 ad ${outcome.name} grants no reward or debit', () async {
      final a = FakeAds()..outcome = outcome;
      final c = create(ads: a);
      await c.load();
      expect(await c.watch(Assist.hint), false);
      expect(c.hintLane, isNull);
      expect(c.coins, 150);
      expect(c.busy, false);
    });
  }
  test('BR-25 rewarded video grants one free assist', () async {
    final a = FakeAds()..outcome = AdOutcome.rewarded;
    final c = create(ads: a);
    await c.load();
    expect(await c.watch(Assist.hint), true);
    expect(c.hintLane, isNotNull);
    expect(c.coins, 150);
    expect(a.calls, 1);
  });
  test(
    'BR-26 overlapping taps cannot double request, reward or move',
    () async {
      final a = FakeAds()..pending = Completer<AdOutcome>();
      final c = create(ads: a);
      await c.load();
      final first = c.watch(Assist.hint);
      expect(await c.watch(Assist.hint), false);
      expect(c.release(0).accepted, false);
      c.restart();
      expect(c.attempts, 1);
      a.pending!.complete(AdOutcome.rewarded);
      expect(await first, true);
      expect(a.calls, 1);
      expect(c.coins, 150);
      expect(c.board.moves, 0);
    },
  );
  test('BR-27 save restores board, history, coins and settings', () async {
    final s = MemoryProgressStore();
    final c = create(store: s);
    await c.load();
    traffic(c);
    c.release(0);
    c.settings(sound: false, haptics: false, reducedMotion: true);
    c.finishOnboarding();
    c.spend(Assist.hint);
    await c.save();
    final r = create(store: s);
    await r.load();
    expect(r.coins, c.coins);
    expect(r.unlocked, 12);
    expect(jsonEncode(r.board.toJson()), jsonEncode(c.board.toJson()));
    expect(r.history.length, 1);
    expect(r.sound, false);
    expect(r.haptics, false);
    expect(r.reducedMotion, true);
    expect(r.onboarded, true);
  });
  test('BR-28 corrupt save recovers safely', () async {
    for (final raw in [
      'not json',
      '{"schema":99}',
      '{"schema":1,"unlocked":-1,"coins":10}',
    ]) {
      final c = create(store: MemoryProgressStore(raw));
      await c.load();
      expect(c.loaded, true);
      expect(c.unlocked, 1);
      expect(c.board.moves, 0);
      expect(c.message, isNotNull);
    }
  });
  test('BR-29 completed save cannot award again at launch', () async {
    final s = MemoryProgressStore();
    final c = create(store: s);
    await c.load();
    win(c);
    await c.save();
    final r = create(store: s);
    await r.load();
    expect(r.coins, 175);
    expect(r.unlocked, 2);
    expect(r.board.phase(r.level), GamePhase.won);
  });
  test(
    'BR-30 daily reward once per date; campaign preserved; consecutive streak',
    () async {
      var today = DateTime(2026, 10, 6);
      final c = create(clock: () => today);
      await c.load();
      c.release(c.level.solution.first);
      final previous = jsonEncode(c.board.toJson());
      c.openDaily();
      win(c);
      expect(c.coins, 225);
      expect(c.unlocked, 1);
      expect(c.streak, 1);
      c.openDaily();
      win(c);
      expect(c.coins, 225);
      c.returnToCampaign();
      expect(jsonEncode(c.board.toJson()), previous);
      today = DateTime(2026, 10, 7);
      c.openDaily();
      win(c);
      expect(c.coins, 300);
      expect(c.streak, 2);
    },
  );
  test('BR-31 expired daily earns no current-date reward', () async {
    var day = DateTime(2026, 10, 6);
    final c = create(clock: () => day);
    await c.load();
    c.openDaily();
    day = DateTime(2026, 10, 7);
    win(c);
    expect(c.coins, 150);
    expect(c.streak, 0);
  });
  for (final outcome in [
    PurchaseOutcome.cancelled,
    PurchaseOutcome.pending,
    PurchaseOutcome.error,
    PurchaseOutcome.unavailable,
  ]) {
    test('BR-32 ${outcome.name} never grants purchase entitlement', () async {
      final p = FakePurchases()..outcome = outcome;
      final c = create(purchases: p);
      await c.load();
      await c.buyRemoveAds();
      expect(c.removeAds, false);
      expect(c.coins, 150);
      expect(c.busy, false);
    });
  }
  test('BR-33 verified purchase and restore/revocation semantics', () async {
    final p = FakePurchases()..outcome = PurchaseOutcome.purchased;
    final c = create(purchases: p);
    await c.load();
    await c.buyRemoveAds();
    expect(c.removeAds, true);
    p.restored = null;
    await c.restorePurchases();
    expect(c.removeAds, true);
    p.restored = false;
    await c.restorePurchases();
    expect(c.removeAds, false);
    p.restored = true;
    await c.restorePurchases();
    expect(c.removeAds, true);
  });
  test('BR-34 interstitial grace, cadence, cooldown and removal', () {
    const p = AdPolicy();
    final now = DateTime(2026, 10, 6);
    expect(p.allows(level: 5, wins: 4, removed: false, now: now), false);
    expect(p.allows(level: 6, wins: 3, removed: false, now: now), false);
    expect(p.allows(level: 6, wins: 4, removed: false, now: now), true);
    expect(p.allows(level: 6, wins: 4, removed: true, now: now), false);
    expect(
      p.allows(
        level: 6,
        wins: 4,
        removed: false,
        now: now,
        lastAd: now.subtract(const Duration(seconds: 179)),
      ),
      false,
    );
  });
  test('BR-35 config cannot remove retention protections', () {
    final p = AdPolicy.fromJson({
      'firstLevel': 0,
      'everyWins': 1,
      'cooldownSeconds': 0,
    });
    expect(p.firstLevel, 6);
    expect(p.everyWins, 3);
    expect(p.cooldownSeconds, 120);
  });
  test('BR-36 analytics records funnel and lifecycle without PII', () async {
    final a = LocalAnalytics();
    final c = create(analytics: a);
    await c.load();
    c.spend(Assist.hint);
    win(c);
    c.lifecycle('paused');
    expect(
      a.events.map((e) => e.name),
      containsAll([
        'session_start',
        'level_start',
        'hint',
        'bus_release',
        'level_win',
        'lifecycle',
      ]),
    );
    expect(a.events.first.properties.containsKey('email'), false);
  });
  test('BR-37 offline ads/store preserve playability', () async {
    final c = create();
    await c.load();
    expect(await c.watch(Assist.hint), false);
    await c.buyRemoveAds();
    expect(c.removeAds, false);
    win(c);
    expect(c.board.phase(c.level), GamePhase.won);
  });
}
