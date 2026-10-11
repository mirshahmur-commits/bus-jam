import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/endless.dart';

/// A reasonable player: board a match when possible, otherwise dig the lane
/// where the bus colour is shallowest, otherwise send the front whose bus
/// comes soonest.
int greedy(EndlessRun r) {
  for (int i = 0; i < r.lanes.length; i++) {
    if (r.lanes[i].isNotEmpty && r.lanes[i].first == r.bus) return i;
  }
  var dig = -1, depth = 1 << 30;
  for (int i = 0; i < r.lanes.length; i++) {
    final d = r.lanes[i].indexOf(r.bus);
    if (d > 0 && d < depth) {
      depth = d;
      dig = i;
    }
  }
  if (dig >= 0 && depth < r.slots - r.waiting.length) return dig;
  var best = -1, bestRank = 1 << 30;
  for (int i = 0; i < r.lanes.length; i++) {
    if (r.lanes[i].isEmpty) continue;
    var rank = r.buses.indexOf(r.lanes[i].first);
    if (rank < 0) rank = 100;
    if (rank < bestRank) {
      bestRank = rank;
      best = i;
    }
  }
  return best;
}

void main() {
  test('EN-01 runs are deterministic for a seed', () {
    List<int> play(int seed) {
      final r = EndlessRun(RushConfig(seed: seed));
      final log = <int>[];
      for (int t = 0; t < 200 && !r.over; t++) {
        r.advance(400);
        final lane = greedy(r);
        if (lane >= 0) r.tap(lane);
        log.add(r.score);
      }
      return log;
    }

    expect(play(7), play(7));
    expect(play(7) == play(8), false);
  });

  test('EN-02 every passenger always has exactly one scheduled seat', () {
    for (final seed in [1, 2, 3, 99, 12345]) {
      final r = EndlessRun(RushConfig(seed: seed, capacity: 3 + seed % 3));
      var step = 0;
      while (!r.over && step < 3000) {
        step++;
        r.advance(200 + step % 500);
        if (step % 97 == 0) r.use(Booster.rainbow);
        if (step % 151 == 0) r.use(Booster.taxi);
        if (step % 211 == 0) r.use(Booster.slow);
        final lane = step % 5 == 0 ? step % r.lanes.length : greedy(r);
        if (lane >= 0) r.tap(lane);
        expect(
          r.seatBalance().values.every((v) => v == 0),
          true,
          reason: 'seed $seed step $step ${r.seatBalance()}',
        );
      }
    }
  });

  test('EN-03 passengers keep arriving and the pace rises', () {
    final r = EndlessRun(const RushConfig(seed: 5));
    final start = r.interval;
    final crowd = r.lanes.fold(0, (n, l) => n + l.length);
    expect(crowd, 28);
    final arrived = r.advance(start * 3);
    expect(arrived.length, 3);
    for (int i = 0; i < 1200 && !r.over; i++) {
      r.advance(100);
      final lane = greedy(r);
      if (lane >= 0) r.tap(lane);
    }
    expect(r.busesSent, greaterThan(5));
    expect(r.interval, lessThan(start));
  });

  test('EN-04 matching passengers board; others wait; full buses leave', () {
    final r = EndlessRun(const RushConfig(seed: 11));
    final lane = r.lanes.indexWhere((l) => l.first == r.bus);
    if (lane >= 0) {
      final m = r.tap(lane);
      expect((m.toBus, m.seat, r.boarded), (true, 0, 1));
      expect(m.points, 10);
    }
    final other = r.lanes.indexWhere((l) => l.isNotEmpty && l.first != r.bus);
    final before = r.waiting.length;
    final m = r.tap(other);
    expect(m.toBus, false);
    expect(r.waiting.length, before + 1);
  });

  test('EN-05 the stop jams when every waiting slot is taken', () {
    final r = EndlessRun(const RushConfig(seed: 3, slots: 2));
    while (!r.over) {
      final lane = r.lanes.indexWhere((l) => l.isNotEmpty && l.first != r.bus);
      r.tap(lane >= 0 ? lane : r.lanes.indexWhere((l) => l.isNotEmpty));
    }
    expect(r.end, RushEnd.slotsFull);
    expect(r.tap(0).accepted, false);
    expect(r.addSlot(), true);
    expect(r.over, false);
    expect(r.addSlot(), false);
  });

  test('EN-06 an idle player is overrun by the crowd', () {
    final r = EndlessRun(const RushConfig(seed: 4));
    r.advance(1000000);
    expect(r.end, RushEnd.overflow);
    expect(r.lanes.every((l) => l.length == r.config.laneCap), true);
  });

  test(
    'EN-07 boosters: rainbow seats anyone, slow halves pace, taxi clears',
    () {
      final r = EndlessRun(const RushConfig(seed: 21));
      final other = r.lanes.indexWhere((l) => l.first != r.bus);
      r.tap(other);
      expect(r.waiting, isNotEmpty);
      final rainbow = r.use(Booster.rainbow)!;
      expect(r.rainbow, true);
      expect(rainbow.fromWaiting, isNotEmpty);
      final lane = r.lanes.indexWhere((l) => l.isNotEmpty);
      expect(r.tap(lane).toBus, true);
      for (int i = 0; i < 31; i++) {
        r.advance(1000);
        final next = greedy(r);
        if (next >= 0 && r.waiting.length < r.slots - 1) r.tap(next);
      }
      expect(r.over, false);
      expect(r.rainbow, false);
      final pace = r.interval;
      r.use(Booster.slow);
      expect(r.interval, pace * 2);
      final second = r.lanes.indexWhere(
        (l) => l.isNotEmpty && l.first != r.bus,
      );
      if (second >= 0) r.tap(second);
      if (r.waiting.isNotEmpty) {
        expect(r.use(Booster.taxi)!.accepted, true);
        expect(r.waiting, isEmpty);
      }
      expect(r.use(Booster.taxi), isNull);
    },
  );

  test('EN-08 upgrades: bigger buses, wider stop, calmer crowd', () {
    final c = RushConfig.fromUpgrades({
      Upgrade.bigBus: 3,
      Upgrade.wideStop: 2,
      Upgrade.calmCrowd: 1,
    }, 1);
    expect((c.capacity, c.slots, c.startInterval), (6, 7, 1550));
    expect(upgradePrice(Upgrade.bigBus, 0), 300);
    expect(upgradePrice(Upgrade.bigBus, 3), isNull);
    final r = EndlessRun(c);
    final lane = r.lanes.indexWhere((l) => l.first == r.bus);
    if (lane >= 0) expect(r.tap(lane).seat, 0);
    expect(r.slots, 7);
  });

  test('EN-09 a careful player reaches a meaningful score', () {
    final scores = <int>[];
    for (int seed = 1; seed <= 20; seed++) {
      final r = EndlessRun(RushConfig(seed: seed));
      while (!r.over && r.clock < 600000) {
        r.advance(350);
        final lane = greedy(r);
        if (lane >= 0) r.tap(lane);
      }
      scores.add(r.score);
    }
    scores.sort();
    // ignore: avoid_print
    print('greedy scores $scores');
    expect(scores[10], greaterThan(300));
  });
}
