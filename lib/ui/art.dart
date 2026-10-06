import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/model.dart';

const ink = Color(0xFF183D38),
    teal = Color(0xFF159A7D),
    cream = Color(0xFFF5F3E8);
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

/// Original vector artwork. All buses and people have color-independent marks.
void paintBus(
  Canvas c,
  Rect rect,
  Bus bus, {
  double opacity = 1,
  bool highlighted = false,
}) {
  c.save();
  if (opacity < 1) {
    c.saveLayer(
      rect.inflate(20),
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
  }
  final color = busColors[bus.color.index], w = rect.width, h = rect.height;
  c.translate(rect.left, rect.top);
  rr(c, Rect.fromLTWH(9, 7, w - 12, h - 8), ink.withValues(alpha: .16), 18);
  for (final y in [h * .22, h * .67]) {
    rr(c, Rect.fromLTWH(0, y, 9, h * .14), const Color(0xFF263F44), 4);
    rr(c, Rect.fromLTWH(w - 9, y, 9, h * .14), const Color(0xFF263F44), 4);
  }
  final body = Rect.fromLTWH(5, 0, w - 10, h - 8);
  c.drawRRect(
    RRect.fromRectAndRadius(body, const Radius.circular(17)),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(w, h),
        [
          Color.lerp(color, Colors.white, .25)!,
          color,
          Color.lerp(color, ink, .12)!,
        ],
        [0, .45, 1],
      ),
  );
  rr(
    c,
    Rect.fromLTWH(10, 4, w - 20, 7),
    Colors.white.withValues(alpha: .35),
    5,
  );
  rr(
    c,
    Rect.fromLTWH(13, h * .16, w - 26, h * .25),
    const Color(0xFF28515C),
    9,
  );
  rr(
    c,
    Rect.fromLTWH(17, h * .19, w * .23, h * .18),
    const Color(0xFF769BAA),
    5,
  );
  c.drawLine(
    Offset(w * .54, h * .18),
    Offset(w * .76, h * .32),
    Paint()
      ..color = Colors.white.withValues(alpha: .35)
      ..strokeWidth = 3,
  );
  rr(
    c,
    Rect.fromLTWH(14, h * .47, w - 28, h * .18),
    Colors.white.withValues(alpha: .25),
    8,
  );
  paintMark(
    c,
    Offset(w / 2, h * .55),
    bus.color.index,
    w * .21,
    ink.withValues(alpha: .65),
  );
  for (int i = 0; i < bus.capacity; i++) {
    c.drawCircle(
      Offset(w * .5 + (i - (bus.capacity - 1) / 2) * 10, h * .74),
      3.4,
      Paint()
        ..color = i < bus.boarded ? Colors.white : ink.withValues(alpha: .24),
    );
  }
  rr(c, Rect.fromLTWH(14, h - 18, 11, 4), const Color(0xFFFFF3BC), 2);
  rr(c, Rect.fromLTWH(w - 25, h - 18, 11, 4), const Color(0xFFFFF3BC), 2);
  if (highlighted) {
    c.drawRRect(
      RRect.fromRectAndRadius(body.inflate(4), const Radius.circular(20)),
      Paint()
        ..color = teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
  if (opacity < 1) {
    c.restore();
  }
  c.restore();
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
  c.drawOval(
    const Rect.fromLTWH(-10, 19, 20, 5),
    Paint()..color = ink.withValues(alpha: .1),
  );
  rr(c, const Rect.fromLTWH(-8, 2, 16, 18), busColors[color.index], 6);
  rr(c, const Rect.fromLTWH(-8, 17, 6, 7), ink, 3);
  rr(c, const Rect.fromLTWH(2, 17, 6, 7), ink, 3);
  c.drawCircle(
    const Offset(0, -4),
    8,
    Paint()..color = const Color(0xFFF0C7A1),
  );
  final hair = Path()
    ..moveTo(-8, -4)
    ..quadraticBezierTo(-9, -14, 0, -13)
    ..quadraticBezierTo(10, -14, 8, -4)
    ..lineTo(4, -9)
    ..lineTo(-6, -7)
    ..close();
  c.drawPath(hair, Paint()..color = const Color(0xFF6D5140));
  c.drawCircle(const Offset(-2.8, -3), 1, Paint()..color = ink);
  c.drawCircle(const Offset(2.8, -3), 1, Paint()..color = ink);
  paintMark(c, const Offset(0, 11), color.index, 7, ink.withValues(alpha: .65));
  c.restore();
}

class CityPainter extends CustomPainter {
  CityPainter({this.hero = false});
  final bool hero;
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    rr(c, Offset.zero & s, const Color(0xFFDDEBE1), 32);
    final road = Path()
      ..moveTo(-30, h * .75)
      ..cubicTo(w * .25, h * .1, w * .55, h * 1.13, w + 40, h * .3);
    c.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFC3D3CB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 83,
    );
    c.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFFAF9ED)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (final item in [
      (w * .12, h * .2, 0),
      (w * .68, h * .1, 1),
      (w * .78, h * .72, 2),
    ]) {
      final x = item.$1, y = item.$2;
      rr(c, Rect.fromLTWH(x + 5, y + 6, 49, 47), ink.withValues(alpha: .09), 9);
      rr(
        c,
        Rect.fromLTWH(x, y, 49, 47),
        [
          const Color(0xFFEDCFB0),
          const Color(0xFFBACCDD),
          const Color(0xFFE9BAAA),
        ][item.$3],
        9,
      );
      rr(
        c,
        Rect.fromLTWH(x - 3, y - 4, 55, 12),
        Colors.white.withValues(alpha: .5),
        5,
      );
      for (int i = 0; i < 3; i++) {
        rr(
          c,
          Rect.fromLTWH(x + 8 + i * 12, y + 18, 6, 12),
          ink.withValues(alpha: .2),
          2,
        );
      }
    }
    for (final p in [
      Offset(w * .09, h * .64),
      Offset(w * .91, h * .26),
      Offset(w * .52, h * .16),
      Offset(w * .61, h * .81),
    ]) {
      rr(c, Rect.fromLTWH(p.dx - 2, p.dy, 4, 16), const Color(0xFF9D8F72), 2);
      c.drawCircle(
        p - const Offset(0, 4),
        15,
        Paint()..color = const Color(0xFF8CBE99),
      );
      c.drawCircle(
        p - const Offset(4, 8),
        9,
        Paint()..color = const Color(0xFFAAD4AD),
      );
    }
    c.save();
    c.translate(w * .27, h * .46);
    c.rotate(-.35);
    paintBus(
      c,
      const Rect.fromLTWH(-36, -55, 72, 112),
      const Bus(0, BusColor.coral),
    );
    c.restore();
    c.save();
    c.translate(w * .57, h * .61);
    c.rotate(.45);
    paintBus(
      c,
      const Rect.fromLTWH(-31, -49, 62, 100),
      const Bus(1, BusColor.blue),
    );
    c.restore();
    for (int i = 0; i < 4; i++) {
      paintPerson(
        c,
        Offset(w * .32 + i * 23, h * .88),
        BusColor.values[i],
        scale: .85,
      );
    }
    if (hero) {
      label(
        c,
        'EVERYONE HAS A PLACE.',
        Offset(w / 2, h - 20),
        size: 10,
        color: ink.withValues(alpha: .55),
      );
    }
  }

  @override
  bool shouldRepaint(CityPainter old) => false;
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
