import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/controller.dart';
import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/game/model.dart';
import 'package:bus_jam/platform/progress_store.dart';
import 'package:bus_jam/platform/monetization.dart';
import 'package:bus_jam/ui/app.dart';

import 'fixtures.dart';

class PendingPriceStore extends OfflinePurchases {
  final result = Completer<String?>();
  @override
  Future<String?> price() => result.future;
}

Future<GameController> mount(
  WidgetTester t, {
  Size size = const Size(390, 844),
  bool tutorial = false,
  PurchasesPort? purchases,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final c = GameController(store: MemoryProgressStore(), purchases: purchases);
  await c.load();
  if (!tutorial) {
    c.finishOnboarding();
  }
  c.settings(sound: false, haptics: false);
  await t.pumpWidget(BusJamApp(controller: c, audioEnabled: false));
  await t.pumpAndSettle();
  return c;
}

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito.ttf'));
    await loader.load();
  });
  testWidgets('UAT-01 first launch, onboarding, first route win, next', (
    t,
  ) async {
    final c = await mount(t, tutorial: true);
    expect(find.text('BUS JAM'), findsOneWidget);
    await tap(t, 'play');
    expect(find.text('Let’s get everyone home.'), findsOneWidget);
    await tap(t, 'tutorial-done');
    expect(c.onboarded, true);
    while (c.board.phase(c.level) == GamePhase.playing) {
      await tap(t, 'lane-${GameEngine.solve(c.level, c.board)!.first}');
    }
    expect(find.byKey(const ValueKey('win')), findsOneWidget);
    expect(c.coins, 175);
    await tap(t, 'next');
    expect(c.level.number, 2);
    expect(t.takeException(), isNull);
  });
  testWidgets('UAT-02 fail, paid continue, victory through real taps', (
    t,
  ) async {
    final c = await mount(t);
    c.level = trafficFixture();
    c.unlocked = 12;
    c.board = Board.initial(c.level);
    c.history = [];
    c.settings(reducedMotion: true);
    await tap(t, 'play');
    for (int i = 0; i < 3; i++) {
      await tap(t, 'lane-0');
    }
    expect(find.byKey(const ValueKey('fail')), findsOneWidget);
    await tap(t, 'continue');
    await tap(t, 'use-coins');
    expect(c.coins, 100);
    expect(c.board.slots, 4);
    await tap(t, 'lane-0');
    await tap(t, 'lane-1');
    expect(find.byKey(const ValueKey('win')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('UAT-03 paid hint, undo, restart and settings', (t) async {
    final c = await mount(t);
    await tap(t, 'play');
    await tap(t, 'hint');
    await tap(t, 'use-coins');
    expect(c.hintLane, isNotNull);
    await tap(t, 'lane-${c.hintLane}');
    await tap(t, 'undo');
    await tap(t, 'use-coins');
    expect(c.board.moves, 0);
    await tap(t, 'restart');
    await tap(t, 'confirm-restart');
    expect(c.attempts, 2);
    await tap(t, 'game-settings');
    await tap(t, 'sound-toggle');
    expect(c.sound, true);
    await tap(t, 'motion-toggle');
    expect(c.reducedMotion, true);
    expect(t.takeException(), isNull);
  });
  testWidgets('UAT-09 settings stay usable while store price is pending', (
    t,
  ) async {
    final store = PendingPriceStore();
    final c = await mount(t, purchases: store);
    await tap(t, 'settings');
    expect(find.text('Checking store price…'), findsOneWidget);
    await tap(t, 'motion-toggle');
    expect(c.reducedMotion, true);
    store.result.complete('1.99 USD');
    await t.pumpAndSettle();
    expect(find.text('1.99 USD'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('UAT-04 daily preserves campaign and routes enforce locks', (
    t,
  ) async {
    final c = await mount(t);
    await tap(t, 'daily');
    expect(c.dailyMode, true);
    await tap(t, 'home-button');
    expect(c.dailyMode, false);
    await tap(t, 'routes');
    expect(find.text('Your routes'), findsOneWidget);
    final locked = t.widget<FilledButton>(
      find.byKey(const ValueKey('level-2')),
    );
    expect(locked.onPressed, isNull);
    await tap(t, 'level-1');
    expect(c.level.number, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets('UAT-05 unavailable video leaves coins and state untouched', (
    t,
  ) async {
    final c = await mount(t);
    await tap(t, 'play');
    await tap(t, 'hint');
    await tap(t, 'watch-ad');
    expect(c.hintLane, isNull);
    expect(c.coins, 150);
    expect(find.textContaining('Video unavailable'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'UAT-06 lifecycle flushes save; relaunch restores exact progress',
    (t) async {
      final s = MemoryProgressStore();
      final c = GameController(store: s);
      await c.load();
      c.finishOnboarding();
      c.settings(sound: false, haptics: false);
      await t.pumpWidget(BusJamApp(controller: c, audioEnabled: false));
      await t.pumpAndSettle();
      await tap(t, 'play');
      await tap(t, 'lane-${c.level.solution.first}');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await c.save();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final r = GameController(store: s);
      await r.load();
      expect(r.board.cursor, c.board.cursor);
      expect(r.board.moves, c.board.moves);
      await t.pumpWidget(
        BusJamApp(
          key: const ValueKey('relaunch'),
          controller: r,
          audioEnabled: false,
        ),
      );
      await t.pumpAndSettle();
      await tap(t, 'play');
      expect(find.text('Route 1'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(375, 667),
    const Size(390, 844),
    const Size(430, 932),
    const Size(768, 1024),
  ]) {
    testWidgets('UAT-07 layout ${size.width}x${size.height}', (t) async {
      await mount(t, size: size);
      await tap(t, 'play');
      await tap(t, 'game-settings');
      expect(find.text('Your kind of calm.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
