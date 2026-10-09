import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/ui/game_scene.dart';
import 'package:bus_jam/game/generator.dart';

void main() {
  test('2.0 scene keeps passenger queue below bus approaches', () {
    for (final width in <double>[320, 375, 390, 430, 520]) {
      for (final number in <int>[1, 3, 10, 20, 30, 35]) {
        final level = LevelGenerator().generate(number);
        final depth = level.lanes
            .map((lane) => lane.length)
            .reduce((a, b) => a > b ? a : b);
        final scene = SceneLayout(
          Size(width, SceneLayout.heightFor(width, level)),
          level.lanes.length,
          level.slots,
          maxDepth: depth,
        );
        final lastBus = scene.depot(0, depth - 1);
        expect(
          scene.queueY,
          greaterThan(lastBus.bottom),
          reason: 'level $number, width $width',
        );
        expect(scene.slot(0).left, greaterThanOrEqualTo(0));
        expect(scene.slot(level.slots - 1).right, lessThanOrEqualTo(width));
        expect(scene.busW, greaterThan(0));
        expect(
          SceneLayout.heightFor(width, level),
          greaterThan(scene.queueY + 65),
        );
      }
    }
  });
}
