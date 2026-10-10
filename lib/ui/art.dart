import 'dart:math';

import 'package:flutter/material.dart';

import '../game/model.dart';
import 'urban_assets.dart';

const ink = Color(0xFF202B39),
    teal = Color(0xFF137888),
    cream = Color(0xFFF2F1ED);
const busColors = [
  Color(0xFFF2583F),
  Color(0xFF3B8DF0),
  Color(0xFFF8C22C),
  Color(0xFF2FC489),
  Color(0xFF9B57E8),
  Color(0xFFF2609F),
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
  // Soft contact shadow anchors the bus to the road.
  c.drawRRect(
    RRect.fromRectAndRadius(
      rect.shift(const Offset(1.5, 3)).deflate(1),
      const Radius.circular(12),
    ),
    Paint()
      ..color = const Color(0xFF162132).withValues(alpha: .22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
  );
  UrbanAssets.instance.paint(
    c,
    rect,
    'bus-${UrbanAssets.colors[bus.color.index]}',
  );
  // Gloss and a slim side highlight add depth without hiding the route art.
  final shine = Rect.fromLTWH(
    rect.left + rect.width * .14,
    rect.top + rect.height * .11,
    rect.width * .08,
    rect.height * .43,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(shine, const Radius.circular(8)),
    Paint()..color = Colors.white.withValues(alpha: .32),
  );
  c.drawLine(
    Offset(rect.right - rect.width * .12, rect.top + rect.height * .2),
    Offset(rect.right - rect.width * .12, rect.bottom - rect.height * .28),
    Paint()
      ..color = Colors.black.withValues(alpha: .12)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round,
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
  // A compact occupancy meter makes partial boarding obvious at a glance.
  final meter = Rect.fromLTWH(
    rect.left + rect.width * .17,
    rect.bottom - 25,
    rect.width * .66,
    3,
  );
  rr(c, meter, ink.withValues(alpha: .45), 2);
  if (bus.boarded > 0) {
    rr(
      c,
      Rect.fromLTWH(
        meter.left,
        meter.top,
        meter.width * bus.boarded / bus.capacity,
        meter.height,
      ),
      const Color(0xFFB5FFBD),
      2,
    );
  }
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

Color shade(Color c, double amount) => Color.lerp(c, Colors.black, amount)!;
Color tint(Color c, double amount) => Color.lerp(c, Colors.white, amount)!;

/// Arena colours: lavender road, stop paving and crowd plaza per terminal.
class ArenaPalette {
  const ArenaPalette(this.sky, this.road, this.curb, this.plaza, this.tile);
  final Color sky, road, curb, plaza, tile;
  static ArenaPalette forId(String id) => switch (id) {
    'terminal-coast' => const ArenaPalette(
      Color(0xFF7FB3C8),
      Color(0xFFC6E3EC),
      Color(0xFFF4FCFF),
      Color(0xFFA9CFDD),
      Color(0xFFDDF0F5),
    ),
    'terminal-garden' => const ArenaPalette(
      Color(0xFF8DBB8F),
      Color(0xFFD3E8CC),
      Color(0xFFF6FFF0),
      Color(0xFFB2D3AA),
      Color(0xFFE4F2DF),
    ),
    'terminal-night' => const ArenaPalette(
      Color(0xFF2B2F57),
      Color(0xFF494E86),
      Color(0xFF9EE6DA),
      Color(0xFF3A3F72),
      Color(0xFF555B98),
    ),
    _ => const ArenaPalette(
      Color(0xFF9A97D6),
      Color(0xFFCBCAF0),
      Color(0xFFF7F7FF),
      Color(0xFFB2B0E4),
      Color(0xFFE2E1F8),
    ),
  };
}

/// Toy-like passenger seen from the front at three-quarter height. [p] is
/// the feet position, [s] the figure height.
void paintRider(
  Canvas c,
  Offset p,
  double s,
  Color color, {
  bool hidden = false,
  bool dim = false,
  int? mark,
  double lift = 0,
  bool arms = false,
}) {
  final base = hidden
      ? const Color(0xFF3C3C48)
      : dim
      ? shade(color, .18)
      : color;
  c.save();
  c.translate(p.dx, p.dy - lift);
  c.drawOval(
    Rect.fromCenter(center: Offset(0, lift), width: s * .62, height: s * .18),
    Paint()..color = Colors.black.withValues(alpha: .16),
  );
  final body = RRect.fromRectAndCorners(
    Rect.fromLTWH(-s * .25, -s * .6, s * .5, s * .58),
    topLeft: Radius.circular(s * .22),
    topRight: Radius.circular(s * .22),
    bottomLeft: Radius.circular(s * .12),
    bottomRight: Radius.circular(s * .12),
  );
  c.drawRRect(
    body,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [tint(base, .25), base, shade(base, .22)],
        stops: const [0, .45, 1],
      ).createShader(body.outerRect),
  );
  if (arms) {
    final arm = Paint()
      ..color = shade(base, .08)
      ..strokeWidth = s * .12
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(-s * .2, -s * .5), Offset(-s * .34, -s * .82), arm);
    c.drawLine(Offset(s * .2, -s * .5), Offset(s * .34, -s * .82), arm);
  }
  final head = Offset(0, -s * .76);
  c.drawCircle(
    head,
    s * .21,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.4, -.5),
        colors: [tint(base, .45), base, shade(base, .2)],
        stops: const [0, .55, 1],
      ).createShader(Rect.fromCircle(center: head, radius: s * .21)),
  );
  c.drawCircle(
    head + Offset(-s * .07, -s * .08),
    s * .05,
    Paint()..color = Colors.white.withValues(alpha: .7),
  );
  if (hidden) {
    label(
      c,
      '?',
      Offset(0, -s * .34),
      size: s * .4,
      color: Colors.white,
      weight: FontWeight.w900,
    );
  } else if (mark != null) {
    paintMark(
      c,
      Offset(0, -s * .3),
      mark,
      s * .16,
      Colors.white.withValues(alpha: .85),
    );
  }
  c.restore();
}

/// Open-top bus seen from the side, facing right, like a toy on the road.
/// [seated] seats are drawn occupied.
void paintCoach(
  Canvas c,
  Rect r,
  BusColor color, {
  int seated = 0,
  String skin = 'classic',
  Set<int> emptySeats = const {},
}) {
  final base = busColors[color.index];
  final w = r.width, h = r.height;
  c.save();
  c.translate(r.left, r.top);
  c.drawOval(
    Rect.fromLTWH(w * .02, h * .86, w * .96, h * .16),
    Paint()..color = Colors.black.withValues(alpha: .14),
  );
  // Interior floor and seats show above the side panel.
  rr(c, Rect.fromLTWH(w * .04, h * .05, w * .9, h * .4), tint(base, .55), 10);
  final rim = Paint()
    ..color = Colors.white.withValues(alpha: .85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(2, h * .035);
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .04, h * .05, w * .9, h * .4),
      const Radius.circular(10),
    ),
    rim,
  );
  for (int seat = 0; seat < busCapacity; seat++) {
    final x = w * (.24 + seat * .22);
    rr(
      c,
      Rect.fromLTWH(x - w * .055, h * .1, w * .11, h * .34),
      const Color(0xFFB5B7D2),
      6,
    );
    rr(
      c,
      Rect.fromLTWH(x - w * .045, h * .13, w * .09, h * .1),
      const Color(0xFFD7D8EA),
      4,
    );
    if (seat < seated && !emptySeats.contains(seat)) {
      paintRider(c, Offset(x + w * .055, h * .48), h * .5, base);
    }
  }
  // Side panel.
  final side = RRect.fromRectAndCorners(
    Rect.fromLTWH(0, h * .36, w, h * .46),
    topLeft: const Radius.circular(10),
    topRight: Radius.circular(h * .18),
    bottomLeft: const Radius.circular(8),
    bottomRight: const Radius.circular(10),
  );
  c.drawRRect(
    side,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [tint(base, .15), base, shade(base, .18)],
      ).createShader(side.outerRect),
  );
  rr(c, Rect.fromLTWH(0, h * .72, w, h * .1), shade(base, .25), 6);
  for (int i = 0; i < 5; i++) {
    rr(
      c,
      Rect.fromLTWH(w * (.06 + i * .17), h * .46, w * .13, h * .14),
      const Color(0xFF235A63),
      4,
    );
    rr(
      c,
      Rect.fromLTWH(w * (.07 + i * .17), h * .47, w * .04, h * .12),
      Colors.white.withValues(alpha: .18),
      3,
    );
  }
  final trim = switch (skin) {
    'royal' => const Color(0xFFFFD66D),
    'neon' => const Color(0xFF91FFF1),
    'metro' => const Color(0xFFE6EAF0),
    'retro' => const Color(0xFFF6F0D2),
    _ => null,
  };
  if (trim != null) {
    rr(c, Rect.fromLTWH(w * .03, h * .64, w * .94, h * .035), trim, 2);
    if (skin == 'retro') {
      rr(c, Rect.fromLTWH(w * .03, h * .69, w * .94, h * .025), trim, 2);
    }
  }
  // Route badge keeps colour matching readable without colour vision.
  final badge = Offset(w * .9, h * .53);
  c.drawCircle(badge, h * .09, Paint()..color = ink);
  paintMark(c, badge, color.index, h * .1, Colors.white);
  for (final x in [w * .22, w * .78]) {
    c.drawCircle(
      Offset(x, h * .84),
      h * .12,
      Paint()..color = const Color(0xFF2B2D3A),
    );
    c.drawCircle(
      Offset(x, h * .84),
      h * .055,
      Paint()..color = const Color(0xFFB9BCD0),
    );
  }
  c.restore();
}
