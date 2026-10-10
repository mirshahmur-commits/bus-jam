import 'dart:math';

import 'package:flutter/material.dart';

import '../game/model.dart';
import 'art.dart';

class DepotPreview extends StatelessWidget {
  const DepotPreview({
    super.key,
    this.skin = 'classic',
    this.terminal = 'terminal-classic',
    this.busOnly = false,
  });
  final String skin, terminal;
  final bool busOnly;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _DepotPainter(skin, terminal, busOnly)),
  );
}

class _DepotPainter extends CustomPainter {
  const _DepotPainter(this.skin, this.terminal, this.busOnly);
  final String skin, terminal;
  final bool busOnly;
  @override
  void paint(Canvas c, Size s) {
    final pal = ArenaPalette.forId(terminal);
    c.save();
    c.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(20)),
    );
    c.drawRect(Offset.zero & s, Paint()..color = pal.sky);
    final roadBottom = busOnly ? s.height : s.height * .62;
    c.drawRect(
      Rect.fromLTWH(0, s.height * .08, s.width, roadBottom - s.height * .08),
      Paint()..color = pal.road,
    );
    c.drawRect(
      Rect.fromLTWH(0, s.height * .1, s.width, 4),
      Paint()..color = pal.curb,
    );
    final busW = min(s.width * .56, (roadBottom - s.height * .12) * 2.0);
    final busH = busW * .46;
    final top = (s.height * .08 + roadBottom) / 2 - busH * .5;
    paintCoach(
      c,
      Rect.fromLTWH(-busW * .55, top, busW, busH),
      BusColor.mint,
      skin: skin,
    );
    paintCoach(
      c,
      Rect.fromLTWH(s.width * .5 - busW * .42, top, busW, busH),
      BusColor.gold,
      seated: 2,
      skin: skin,
    );
    if (!busOnly) {
      c.drawRect(
        Rect.fromLTWH(0, roadBottom, s.width, s.height - roadBottom),
        Paint()..color = pal.tile,
      );
      final step = s.width / 9;
      const crowd = [2, 0, 4, 1, 2, 3, 5, 0];
      for (int i = 0; i < crowd.length; i++) {
        paintRider(
          c,
          Offset(step * (i + 1), s.height - 8),
          min(step * 1.05, (s.height - roadBottom) * .95),
          busColors[crowd[i]],
          hidden: i == 5,
        );
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _DepotPainter old) =>
      skin != old.skin || terminal != old.terminal || busOnly != old.busOnly;
}
