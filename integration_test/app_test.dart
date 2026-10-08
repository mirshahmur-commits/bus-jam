import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bus_jam/main.dart' as app;
import 'package:bus_jam/game/controller.dart';
import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/game/model.dart';
import 'package:bus_jam/ui/app.dart';

import '../test/fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native player journey: first launch to save/restore, recovery and settings',
    (t) async {
      await SharedPreferencesAsync().remove('bus_jam.progress.v1');
      await app.main();
      await t.pumpAndSettle();
      GameController controller() =>
          t.widget<BusJamApp>(find.byType(BusJamApp)).controller;
      Future<void> waitForResult() async {
        final phase = controller().board.phase(controller().level);
        if (phase == GamePhase.playing) return;
        final result = find.byKey(ValueKey(phase == GamePhase.won ? 'win' : 'fail'));
        // Native pumpAndSettle can finish between motion and the result timer.
        for (int frame = 0; frame < 40 && result.evaluate().isEmpty; frame++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(result, findsOneWidget);
      }

      Future<void> tap(String key) async {
        final f = find.byKey(ValueKey(key));
        await t.ensureVisible(f);
        await t.tap(f);
        await t.pumpAndSettle();
        if (key.startsWith('lane-')) await waitForResult();
      }

      Future<void> shot(String name) async {
        await binding.takeScreenshot(name);
      }

      await shot('native-home');
      await tap('play');
      await tap('tutorial-done');
      final c = controller();
      c.settings(sound: false, haptics: false);
      await shot('native-game');
      // A second real tap is accepted before the first 440 ms departure ends.
      final route = GameEngine.solve(c.level, c.board)!;
      for (final lane in route) {
        final target = find.byKey(ValueKey('lane-$lane'));
        await t.ensureVisible(target);
        await t.tap(target);
        await t.pump(const Duration(milliseconds: 40));
      }
      expect(c.board.phase(c.level), GamePhase.won);
      await t.pumpAndSettle();
      await waitForResult();
      expect(find.byKey(const ValueKey('win')), findsOneWidget);
      expect(c.coins, 175);
      await shot('native-win');
      await tap('next');
      expect(c.level.number, 2);
      await tap('hint');
      await tap('use-coins');
      expect(c.hintLane, isNotNull);
      await tap('lane-${c.hintLane}');
      await c.save();
      final saved = c.board.toJson();
      await app.main();
      await t.pumpAndSettle();
      final restored = controller();
      expect(restored.board.toJson(), saved);
      await tap('play');
      restored.level = trafficFixture();
      restored.unlocked = 12;
      restored.restart();
      await t.pumpAndSettle();
      for (int i = 0; i < 3; i++) {
        await tap('lane-0');
      }
      expect(find.byKey(const ValueKey('fail')), findsOneWidget);
      await shot('native-fail');
      await tap('continue');
      await tap('use-coins');
      expect(restored.board.slots, 4);
      await tap('lane-0');
      await tap('lane-1');
      expect(find.byKey(const ValueKey('win')), findsOneWidget);
      restored.restart();
      await t.pumpAndSettle();
      await tap('game-settings');
      await tap('motion-toggle');
      expect(restored.reducedMotion, true);
      await shot('native-settings');
      await tap('sheet-close');
      final collector = controller();
      collector.openLevel(collector.unlocked);
      await t.pumpAndSettle();
      for (int number = 13; number <= 19; number++) {
        for (final lane in collector.level.solution) {
          await tap('lane-$lane');
        }
        expect(collector.lastResult!.stars, 3);
        if (number < 19) await tap('next');
      }
      expect(collector.coins, 300);
      await tap('win-garage');
      await tap('cosmetic-metro');
      expect(collector.coins, 0);
      expect(collector.selectedBus, 'metro');
      await shot('native-garage');
      await collector.save();
      await app.main();
      await t.pumpAndSettle();
      expect(controller().selectedBus, 'metro');
      expect(controller().totalStars, 24);
      await tap('routes');
      await shot('native-map');
      expect(t.takeException(), isNull);
      binding.reportData!.addAll({
        'version': '1.1.0+2',
        'journey': 'Passed',
        'nativePlatform': true,
        'sandboxPayments': 'Not run',
        'realAds': 'Not run',
        'rapidInput': 'Passed',
        'collectionEarnBuyRestore': 'Passed',
        'starsAndRecords': 'Passed',
        'liveGameCenter': 'Not run',
      });
    },
  );
}
