import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/endless.dart';
import 'package:bus_jam/ui/urban_assets.dart';

import 'widget_test.dart' show mount, tap;

/// Pumps real frames: the rush clock caps each frame at 100 ms.
Future<void> frames(WidgetTester t, int ms) async {
  for (int i = 0; i < ms ~/ 16; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<void> press(WidgetTester t, String key) async {
  await t.tap(find.byKey(ValueKey(key)));
  // The rush clock keeps ticking, so settle by time rather than idleness.
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => UrbanAssets.instance.load());

  testWidgets(
    'UAT-10 rush: crowd keeps arriving, taps score, pause stops the clock',
    (t) async {
      final c = await mount(t);
      await t.tap(find.byKey(const ValueKey('rush')));
      await t.pump();
      final run = c.rush!;
      final crowd = run.lanes.fold(0, (n, l) => n + l.length);
      await frames(t, run.interval * 2 + 100);
      expect(run.lanes.fold(0, (n, l) => n + l.length), greaterThan(crowd));
      final lane = run.lanes.indexWhere((l) => l.first == run.bus);
      await press(t, 'lane-${lane >= 0 ? lane : 0}');
      expect(run.delivered + run.waiting.length, greaterThan(0));
      await press(t, 'rush-pause');
      expect(find.byKey(const ValueKey('rush-resume')), findsOneWidget);
      final clock = run.clock;
      await frames(t, 2000);
      expect(run.clock, clock);
      await press(t, 'rush-resume');
      await frames(t, 500);
      expect(run.clock, greaterThan(clock));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('UAT-11 rush: boosters, jam, continue, record and coins', (
    t,
  ) async {
    final c = await mount(t);
    await t.tap(find.byKey(const ValueKey('rush')));
    await t.pump();
    final run = c.rush!;
    await press(t, 'booster-slow');
    expect(run.slow, true);
    expect(c.boosters[Booster.slow], 0);
    // Fill the slots with wrong colours until the stop jams.
    while (!run.over) {
      if (run.lanes.every((l) => l.isEmpty)) {
        await frames(t, 500);
        continue;
      }
      final lane = run.lanes.indexWhere(
        (l) => l.isNotEmpty && l.first != run.bus,
      );
      await press(
        t,
        'lane-${lane >= 0 ? lane : run.lanes.indexWhere((l) => l.isNotEmpty)}',
      );
    }
    expect(find.byKey(const ValueKey('rush-over')), findsOneWidget);
    await press(t, 'rush-taxi');
    expect(run.over, false);
    expect(run.waiting, isEmpty);
    while (!run.over) {
      if (run.lanes.every((l) => l.isEmpty)) {
        await frames(t, 500);
        continue;
      }
      final lane = run.lanes.indexWhere(
        (l) => l.isNotEmpty && l.first != run.bus,
      );
      await press(
        t,
        'lane-${lane >= 0 ? lane : run.lanes.indexWhere((l) => l.isNotEmpty)}',
      );
    }
    final coins = c.coins;
    await press(t, 'rush-again');
    expect(c.rushRuns, 1);
    expect(c.bestScore, run.score);
    expect(c.coins, coins + run.coins);
    expect(identical(c.rush, run), false);
    await press(t, 'rush-pause');
    await press(t, 'rush-quit');
    expect(find.byKey(const ValueKey('best-score')), findsOneWidget);
    expect(c.rushRuns, 2);
    expect(t.takeException(), isNull);
  });

  testWidgets('UAT-12 shop sells upgrades and boosters', (t) async {
    final c = await mount(t);
    c.coins = 400;
    await tap(t, 'garage-goal');
    await tap(t, 'upgrade-bigBus');
    expect(c.upgrades[Upgrade.bigBus], 1);
    expect(c.coins, 100);
    await tap(t, 'buy-taxi');
    expect((c.boosters[Booster.taxi], c.coins), (2, 50));
    expect(t.takeException(), isNull);
  });
}
