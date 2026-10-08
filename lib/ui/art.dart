import 'dart:math';

import 'package:flutter/material.dart';

import '../game/model.dart';
import 'urban_assets.dart';

const ink = Color(0xFF202B39),
    teal = Color(0xFF137888),
    cream = Color(0xFFF2F1ED);
const busColors = [
  Color(0xFFF37965),
  Color(0xFF5BA6EA),
  Color(0xFFF6C657),
  Color(0xFF58C7A0),
  Color(0xFFAA8BDF),
  Color(0xFFED8FB5),
];
const colorNames = ['Coral', 'Blue', 'Gold', 'Mint', 'Violet', 'Rose'];
const colorMarks = ['♥', '●', '★', '◆', '✦', '✿'];

void paintMark(Canvas c, Offset p, int kind, double size, Color color) {
  c.save();
  c.translate(p.dx, p.dy);
  final paint = Paint()..color = color;
  final r = size / 2;
  if (kind == 1) {
    c.drawCircle(Offset.zero, r, paint);
  } else if (kind == 0) {
    final path = Path()
      ..moveTo(0, r * .9)
      ..cubicTo(-r * 1.8, -r * .2, -r * .5, -r * 1.6, 0, -r * .5)
      ..cubicTo(r * .5, -r * 1.6, r * 1.8, -r * .2, 0, r * .9);
    c.drawPath(path, paint);
  } else if (kind == 3) {
    final path = Path()
      ..moveTo(0, -r)
      ..lineTo(r, 0)
      ..lineTo(0, r)
      ..lineTo(-r, 0)
      ..close();
    c.drawPath(path, paint);
  } else {
    final tips = kind == 2
        ? 5
        : kind == 4
        ? 4
        : 6;
    final path = Path();
    for (int i = 0; i < tips * 2; i++) {
      final a = -pi / 2 + i * pi / tips, rad = i.isEven ? r : r * .45;
      final q = Offset(cos(a) * rad, sin(a) * rad);
      if (i == 0) {
        path.moveTo(q.dx, q.dy);
      } else {
        path.lineTo(q.dx, q.dy);
      }
    }
    path.close();
    c.drawPath(path, paint);
  }
  c.restore();
}

void label(
  Canvas canvas,
  String value,
  Offset offset, {
  double size = 12,
  Color color = ink,
  FontWeight weight = FontWeight.w800,
  bool center = true,
}) {
  final p = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFamily: 'Nunito',
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  p.paint(canvas, center ? offset - Offset(p.width / 2, p.height / 2) : offset);
}

void rr(Canvas c, Rect r, Color color, double radius) => c.drawRRect(
  RRect.fromRectAndRadius(r, Radius.circular(radius)),
  Paint()..color = color,
);

/// Approved urban game sprites; live occupancy and hints remain code-drawn.
void paintBus(
  Canvas c,
  Rect rect,
  Bus bus, {
  double opacity = 1,
  bool highlighted = false,
  String skin = 'classic',
}) {
  c.save();
  if (opacity < 1) {
    c.saveLayer(
      rect.inflate(6),
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
  }
  if (highlighted) {
    c.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(11)),
      Paint()
        ..color = const Color(0xFFF6C657)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
  UrbanAssets.instance.paint(
    c,
    rect,
    'bus-${UrbanAssets.colors[bus.color.index]}',
  );
  final trim = skin == 'royal'
      ? const Color(0xFFFFD66D)
      : skin == 'neon'
      ? const Color(0xFF91FFF1)
      : const Color(0xFFF6F3DC);
  if (skin != 'classic') {
    final stripeY = rect.top + rect.height * .67;
    c.drawLine(
      Offset(rect.left + rect.width * .17, stripeY),
      Offset(rect.right - rect.width * .17, stripeY),
      Paint()
        ..color = trim
        ..strokeWidth = skin == 'retro' ? 4 : 2.5,
    );
    if (skin == 'retro') {
      c.drawLine(
        Offset(rect.left + rect.width * .17, stripeY + 7),
        Offset(rect.right - rect.width * .17, stripeY + 7),
        Paint()
          ..color = trim
          ..strokeWidth = 3,
      );
    }
    if (skin == 'neon' || skin == 'royal') {
      c.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(rect.width * .11),
          const Radius.circular(9),
        ),
        Paint()
          ..color = trim.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (skin == 'metro') {
      rr(
        c,
        Rect.fromLTWH(
          rect.left + rect.width * .12,
          rect.top + rect.height * .32,
          rect.width * .07,
          rect.height * .25,
        ),
        trim,
        3,
      );
      rr(
        c,
        Rect.fromLTWH(
          rect.right - rect.width * .19,
          rect.top + rect.height * .32,
          rect.width * .07,
          rect.height * .25,
        ),
        trim,
        3,
      );
    }
  }
  // Route colour and symbol are fixed by the puzzle, including on paid skins.
  c.drawCircle(Offset(rect.center.dx, rect.top + 17), 8, Paint()..color = ink);
  paintMark(
    c,
    Offset(rect.center.dx, rect.top + 17),
    bus.color.index,
    10,
    Colors.white,
  );
  final badge = Rect.fromCenter(
    center: Offset(rect.center.dx, rect.bottom - 10),
    width: min(46, rect.width - 6),
    height: 18,
  );
  rr(c, badge, const Color(0xFF18222F), 4);
  label(
    c,
    '${bus.boarded}/${bus.capacity}',
    badge.center,
    size: 11,
    color: Colors.white,
  );
  if (opacity < 1) c.restore();
  c.restore();
}

class TerminalPalette {
  const TerminalPalette(this.floor, this.road, this.line);
  final Color floor, road, line;
  static TerminalPalette forId(String id) => switch (id) {
    'terminal-coast' => const TerminalPalette(
      Color(0xFFD8ECEE),
      Color(0xFF42798B),
      Color(0xFFE3FCFF),
    ),
    'terminal-garden' => const TerminalPalette(
      Color(0xFFE1EBDD),
      Color(0xFF567968),
      Color(0xFFF3FFE5),
    ),
    'terminal-night' => const TerminalPalette(
      Color(0xFF303E59),
      Color(0xFF23304B),
      Color(0xFF8ADFCF),
    ),
    _ => const TerminalPalette(
      Color(0xFFE1E5E9),
      Color(0xFF526274),
      Color(0xFFF4F7FA),
    ),
  };
}

void paintPerson(
  Canvas c,
  Offset p,
  BusColor color, {
  double scale = 1,
  double bounce = 0,
}) {
  c.save();
  c.translate(p.dx, p.dy + bounce);
  c.scale(scale);
  UrbanAssets.instance.paint(
    c,
    const Rect.fromLTWH(-13, -26, 26, 52),
    'person-${UrbanAssets.colors[color.index]}',
  );
  // A readable duplicate of the shirt symbol keeps matching accessible at 1x.
  c.drawCircle(const Offset(10, 8), 6.5, Paint()..color = ink);
  paintMark(c, const Offset(10, 8), color.index, 8, Colors.white);
  c.restore();
}

class CityPainter extends CustomPainter {
  CityPainter({this.hero = false});
  final bool hero;
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    UrbanAssets.instance.paint(c, Offset.zero & s, 'city', fit: BoxFit.cover);
    paintBus(
      c,
      Rect.fromLTWH(w * .28, h * .36, 66, 108),
      const Bus(0, BusColor.coral),
    );
    paintBus(
      c,
      Rect.fromLTWH(w * .57, h * .48, 58, 96),
      const Bus(1, BusColor.blue),
    );
    for (int i = 0; i < 4; i++) {
      paintPerson(
        c,
        Offset(w * .12 + i * 27, h * .81),
        BusColor.values[i],
        scale: .85,
      );
    }
    if (hero) {
      rr(c, Rect.fromLTWH(0, h - 31, w, 31), ink.withValues(alpha: .87), 0);
      label(
        c,
        'FIND THE ORDER. OWN THE ROUTE.',
        Offset(w / 2, h - 15),
        size: 10,
        color: Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(CityPainter old) => hero != old.hero;
}

class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.t);
  final double t;
  @override
  void paint(Canvas c, Size s) {
    final rng = Random(17);
    for (int i = 0; i < 45; i++) {
      final x = rng.nextDouble() * s.width,
          y = (rng.nextDouble() * s.height + t * s.height * .6) % s.height;
      c.save();
      c.translate(x, y);
      c.rotate(t * 4 + i);
      rr(
        c,
        const Rect.fromLTWH(-3, -5, 6, 10),
        busColors[i % 6].withValues(alpha: .8),
        2,
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => t != old.t;
}
