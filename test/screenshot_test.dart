import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/controller.dart';
import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/game/model.dart';
import 'package:bus_jam/platform/progress_store.dart';
import 'package:bus_jam/ui/app.dart';
import 'package:bus_jam/ui/urban_assets.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await UrbanAssets.instance.load();
    final loader = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('UAT visual evidence: home, gameplay, win, fail, settings', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = GameController(store: MemoryProgressStore());
    await c.load();
    c.finishOnboarding();
    c.settings(sound: false, haptics: false, reducedMotion: true);
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: BusJamApp(controller: c, audioEnabled: false),
      ),
    );
    await t.pumpAndSettle();
    Future<void> shot(String name) async {
      await t.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await Directory('docs/evidence/screens').create(recursive: true);
        await File(
          'docs/evidence/screens/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      });
    }

    Future<void> press(String id) async {
      final f = find.byKey(ValueKey(id));
      await t.ensureVisible(f);
      await t.tap(f);
      await t.pumpAndSettle();
    }

    await shot('01-home');
    await press('play');
    await shot('02-gameplay');
    while (c.board.phase(c.level) == GamePhase.playing) {
      await press('lane-${GameEngine.solve(c.level, c.board)!.first}');
    }
    await shot('03-win');
    c.level = trafficFixture();
    c.unlocked = 12;
    c.restart();
    await t.pumpAndSettle();
    for (int i = 0; i < 3; i++) {
      await press('lane-0');
    }
    await shot('04-fail');
    c.restart();
    await t.pumpAndSettle();
    await press('game-settings');
    await shot('05-settings');
    expect(t.takeException(), isNull);
  });
}
