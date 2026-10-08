import 'package:flutter/material.dart';

import '../game/model.dart';
import 'art.dart';
import 'urban_assets.dart';

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
    final palette = TerminalPalette.forId(terminal);
    rr(c, Offset.zero & s, palette.floor, 20);
    if (!busOnly) {
      c.save();
      c.clipRRect(
        RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(20)),
      );
      UrbanAssets.instance.paint(
        c,
        Rect.fromLTWH(0, 0, s.width, s.height * .66),
        'city',
        fit: BoxFit.cover,
      );
      rr(
        c,
        Rect.fromLTWH(0, s.height * .48, s.width, s.height * .52),
        palette.road,
        0,
      );
      for (int i = 0; i < 3; i++) {
        final x = s.width * (.17 + i * .33);
        c.drawLine(
          Offset(x - 38, s.height * .6),
          Offset(x + 38, s.height * .6),
          Paint()
            ..color = palette.line.withValues(alpha: .65)
            ..strokeWidth = 2,
        );
        paintBus(
          c,
          Rect.fromCenter(
            center: Offset(x, s.height * .62),
            width: 58,
            height: 90,
          ),
          Bus(i, BusColor.values[i], capacity: i == 1 ? 4 : 2),
          skin: skin,
        );
      }
      c.restore();
    } else {
      paintBus(
        c,
        Rect.fromCenter(
          center: Offset(s.width * .35, s.height / 2),
          width: s.height * .57,
          height: s.height * .9,
        ),
        const Bus(0, BusColor.blue, capacity: 4),
        skin: skin,
      );
      paintBus(
        c,
        Rect.fromCenter(
          center: Offset(s.width * .69, s.height / 2),
          width: s.height * .57,
          height: s.height * .9,
        ),
        const Bus(1, BusColor.coral, capacity: 2),
        skin: skin,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DepotPainter old) =>
      skin != old.skin || terminal != old.terminal || busOnly != old.busOnly;
}
