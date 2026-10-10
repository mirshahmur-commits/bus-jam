import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/controller.dart';
import 'package:bus_jam/game/model.dart';
import 'package:bus_jam/ui/game_scene.dart';
import 'package:bus_jam/ui/urban_assets.dart';

import 'widget_test.dart' show mount, tap;
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => UrbanAssets.instance.load());

  testWidgets(
    'Rapid taps send five passengers while earlier ones are still walking',
    (t) async {
      final c = await mount(t);
      c.level = trafficFixture();
      c.unlocked = 12;
      c.restart();
      await tap(t, 'play');
      for (int i = 0; i < trafficFailure.length; i++) {
        await t.tap(find.byKey(ValueKey('lane-${trafficFailure[i]}')));
        await t.pump(const Duration(milliseconds: 40));
        expect(c.board.moves, i + 1);
      }
      expect(c.board.phase(c.level), GamePhase.failed);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('fail')), findsOneWidget);
      await tap(t, 'fail-undo');
      expect(c.board.moves, 4);
      expect(c.coins, 150);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Play is visible without scrolling on a small phone and garage goal opens the shop',
    (t) async {
      await mount(t, size: const Size(320, 568));
      final play = find.byKey(const ValueKey('play'));
      expect(t.getRect(play).bottom, lessThan(500));
      await tap(t, 'garage-goal');
      expect(find.byKey(const ValueKey('garage')), findsOneWidget);
      expect(find.text('Metro Line'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Garage unlock debits once, equips the visible gameplay style and restores it',
    (t) async {
      final c = await mount(t);
      c.coins = 800;
      c.settings(sound: false);
      await tap(t, 'garage-goal');
      await tap(t, 'cosmetic-metro');
      expect(c.coins, 500);
      expect(c.selectedBus, 'metro');
      final selected = t.widget<FilledButton>(
        find.byKey(const ValueKey('cosmetic-metro')),
      );
      expect(selected.onPressed, isNull);
      await tap(t, 'cosmetic-terminal-coast');
      expect(c.coins, 0);
      expect(c.selectedTerminal, 'terminal-coast');
      await tap(t, 'garage-back');
      await tap(t, 'play');
      final painter =
          t
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(GameScene),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as ArenaPainter;
      expect(painter.skin, 'metro');
      expect(painter.terminal, 'terminal-coast');
      await c.save();
      final r = GameController(store: c.store);
      await r.load();
      expect(r.selectedBus, 'metro');
      expect(r.selectedTerminal, 'terminal-coast');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Bus line-up shows every remaining bus without a debit or move', (
    t,
  ) async {
    final c = await mount(t);
    c.unlocked = 29;
    c.openLevel(29);
    await tap(t, 'play');
    await tap(t, 'queue-preview');
    expect(find.text('Bus line-up'), findsOneWidget);
    expect(find.byType(Chip), findsNWidgets(c.level.busCount));
    expect(c.coins, 150);
    expect(c.board.moves, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Star result, personal record, replay and route map agree after real taps',
    (t) async {
      final c = await mount(t);
      await tap(t, 'play');
      await tap(t, 'hint');
      await tap(t, 'use-coins');
      for (final lane in c.level.solution) {
        await tap(t, 'lane-$lane');
      }
      expect(find.text('1850'), findsOneWidget);
      expect(c.routeRecord(1)!.stars, 2);
      await tap(t, 'replay');
      for (final lane in c.level.solution) {
        await tap(t, 'lane-$lane');
      }
      expect(find.text('2000'), findsOneWidget);
      expect(c.routeRecord(1)!.stars, 3);
      expect(c.coins, 150);
      await t.tap(find.text('Home').last);
      await t.pumpAndSettle();
      await tap(t, 'routes');
      expect(find.text('★★★'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
