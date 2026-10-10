import 'dart:math';

import 'package:flutter/material.dart';

import '../game/model.dart';

const ink = Color(0xFF2A2660),
    teal = Color(0xFF5B4FD6),
    cream = Color(0xFFF1F0FF);
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

Color shade(Color c, double amount) => Color.lerp(c, Colors.black, amount)!;
Color tint(Color c, double amount) => Color.lerp(c, Colors.white, amount)!;

/// Arena colours: sky, road, curb, stop paving, ground and crowd corridor.
class ArenaPalette {
  const ArenaPalette(
    this.sky,
    this.road,
    this.curb,
    this.stop,
    this.ground,
    this.corridor,
    this.ink,
  );
  final Color sky, road, curb, stop, ground, corridor, ink;
  static ArenaPalette forId(String id) => switch (id) {
    'terminal-coast' => const ArenaPalette(
      Color(0xFF6FA9D6),
      Color(0xFFB7D9EE),
      Color(0xFFF4FBFF),
      Color(0xFFDDEFF9),
      Color(0xFF93C2E2),
      Color(0xFFE9F5FC),
      Color(0xFF214A6E),
    ),
    'terminal-garden' => const ArenaPalette(
      Color(0xFF7DBA86),
      Color(0xFFC6E5C3),
      Color(0xFFF6FFF2),
      Color(0xFFE2F2DD),
      Color(0xFF9FCF9F),
      Color(0xFFEDF8E9),
      Color(0xFF2C5A33),
    ),
    'terminal-night' => const ArenaPalette(
      Color(0xFF26295A),
      Color(0xFF41458A),
      Color(0xFF9EE6DA),
      Color(0xFF555AA0),
      Color(0xFF353A78),
      Color(0xFF4A4F92),
      Color(0xFF14163A),
    ),
    _ => const ArenaPalette(
      Color(0xFF8E8AD6),
      Color(0xFFC3C1EF),
      Color(0xFFFFFFFF),
      Color(0xFFDFDEF8),
      Color(0xFFA7A4E1),
      Color(0xFFEDECFC),
      Color(0xFF3B3680),
    ),
  };
}

const hiddenBody = Color(0xFF3A3946);

/// Chunky toy passenger. [p] is the feet position, [s] the figure height.
void paintRider(
  Canvas c,
  Offset p,
  double s,
  Color color, {
  bool hidden = false,
  int? mark,
  bool arms = false,
  double lean = 0,
  bool shadow = true,
}) {
  final base = hidden ? hiddenBody : color;
  final dark = shade(base, .22);
  c.save();
  c.translate(p.dx, p.dy);
  if (shadow) {
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * .62, height: s * .16),
      Paint()..color = Colors.black.withValues(alpha: .18),
    );
  }
  c.rotate(lean);
  final limb = Paint()..strokeCap = StrokeCap.round;
  // Legs.
  limb
    ..color = dark
    ..strokeWidth = s * .14;
  c.drawLine(Offset(-s * .09, -s * .27), Offset(-s * .1, -s * .05), limb);
  c.drawLine(Offset(s * .09, -s * .27), Offset(s * .1, -s * .05), limb);
  // Arms behind the body when raised, beside it when walking.
  limb
    ..color = shade(base, .1)
    ..strokeWidth = s * .12;
  if (arms) {
    c.drawLine(Offset(-s * .17, -s * .58), Offset(-s * .3, -s * .9), limb);
    c.drawLine(Offset(s * .17, -s * .58), Offset(s * .3, -s * .9), limb);
  }
  final body = RRect.fromRectAndCorners(
    Rect.fromLTWH(-s * .23, -s * .66, s * .46, s * .44),
    topLeft: Radius.circular(s * .2),
    topRight: Radius.circular(s * .2),
    bottomLeft: Radius.circular(s * .12),
    bottomRight: Radius.circular(s * .12),
  );
  c.drawRRect(
    body,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [tint(base, .3), base, dark],
        stops: const [0, .42, 1],
      ).createShader(body.outerRect),
  );
  if (!arms) {
    c.drawLine(Offset(-s * .22, -s * .56), Offset(-s * .27, -s * .34), limb);
    c.drawLine(Offset(s * .22, -s * .56), Offset(s * .27, -s * .34), limb);
  }
  final head = Offset(0, -s * .84);
  final r = s * .19;
  c.drawCircle(
    head,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.45),
        colors: [tint(base, .5), base, dark],
        stops: const [0, .55, 1],
      ).createShader(Rect.fromCircle(center: head, radius: r)),
  );
  c.drawCircle(
    head + Offset(-r * .38, -r * .42),
    r * .24,
    Paint()..color = Colors.white.withValues(alpha: .75),
  );
  if (hidden) {
    label(
      c,
      '?',
      head + Offset(0, r * .08),
      size: r * 1.45,
      color: Colors.white,
      weight: FontWeight.w900,
    );
  } else if (mark != null) {
    paintMark(
      c,
      Offset(0, -s * .46),
      mark,
      s * .13,
      Colors.white.withValues(alpha: .8),
    );
  }
  c.restore();
}

/// Open-top toy bus seen from the side, facing right. Seated passengers sit
/// between the seat backs; [emptySeats] are still on their way.
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
    Rect.fromLTWH(w * .03, h * .88, w * .94, h * .14),
    Paint()..color = Colors.black.withValues(alpha: .16),
  );
  // Glass cabin: a light frame over the seats.
  final cabin = RRect.fromRectAndCorners(
    Rect.fromLTWH(w * .05, h * .04, w * .86, h * .5),
    topLeft: Radius.circular(h * .1),
    topRight: Radius.circular(h * .16),
  );
  c.drawRRect(cabin, Paint()..color = tint(base, .72).withValues(alpha: .7));
  for (int seat = 0; seat < busCapacity; seat++) {
    final x = w * (.27 + seat * .22);
    final back = Rect.fromLTWH(x - w * .065, h * .13, w * .13, h * .42);
    rr(c, back, const Color(0xFFA3A6C6), h * .06);
    rr(
      c,
      Rect.fromLTWH(
        back.left + w * .012,
        back.top + h * .03,
        back.width - w * .024,
        h * .13,
      ),
      const Color(0xFFCDCFE6),
      h * .04,
    );
    if (seat < seated && !emptySeats.contains(seat)) {
      paintRider(c, Offset(x + w * .07, h * .8), h * .56, base, shadow: false);
    }
  }
  final frame = Paint()
    ..color = Colors.white.withValues(alpha: .92)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(2.0, h * .045);
  c.drawRRect(cabin, frame);
  for (final x in [.38, .6]) {
    c.drawLine(
      Offset(w * x, h * .06),
      Offset(w * x, h * .5),
      frame..strokeWidth = max(1.5, h * .025),
    );
  }
  // Body.
  final side = RRect.fromRectAndCorners(
    Rect.fromLTWH(0, h * .48, w, h * .38),
    topLeft: Radius.circular(h * .08),
    topRight: Radius.circular(h * .2),
    bottomLeft: Radius.circular(h * .1),
    bottomRight: Radius.circular(h * .12),
  );
  c.drawRRect(
    side,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [tint(base, .22), base, shade(base, .12)],
        stops: const [0, .4, 1],
      ).createShader(side.outerRect),
  );
  rr(
    c,
    Rect.fromLTWH(w * .01, h * .48, w * .97, h * .045),
    tint(base, .45),
    h * .02,
  );
  for (int i = 0; i < 5; i++) {
    final win = Rect.fromLTWH(w * (.07 + i * .165), h * .57, w * .13, h * .12);
    rr(c, win, const Color(0xFF1F5961), h * .03);
    rr(
      c,
      Rect.fromLTWH(
        win.left + win.width * .1,
        win.top + h * .015,
        win.width * .25,
        win.height * .7,
      ),
      Colors.white.withValues(alpha: .22),
      h * .02,
    );
  }
  rr(
    c,
    Rect.fromLTWH(w * .005, h * .76, w * .99, h * .1),
    shade(base, .28),
    h * .05,
  );
  rr(
    c,
    Rect.fromLTWH(w * .94, h * .62, w * .045, h * .07),
    const Color(0xFFFFE58A),
    h * .02,
  );
  final trim = switch (skin) {
    'royal' => const Color(0xFFFFD66D),
    'neon' => const Color(0xFF91FFF1),
    'metro' => const Color(0xFFE6EAF0),
    'retro' => const Color(0xFFF6F0D2),
    _ => null,
  };
  if (trim != null) {
    rr(c, Rect.fromLTWH(w * .03, h * .705, w * .9, h * .03), trim, 2);
    if (skin == 'retro') {
      rr(c, Rect.fromLTWH(w * .03, h * .745, w * .9, h * .02), trim, 2);
    }
  }
  // Route badge keeps colour matching readable without colour vision.
  final badge = Offset(w * .86, h * .53);
  c.drawCircle(badge, h * .075, Paint()..color = Colors.white);
  paintMark(c, badge, color.index, h * .085, shade(base, .2));
  for (final x in [w * .2, w * .8]) {
    c.drawCircle(Offset(x, h * .86), h * .15, Paint()..color = shade(base, .4));
    c.drawCircle(
      Offset(x, h * .87),
      h * .12,
      Paint()..color = const Color(0xFF2B2C3A),
    );
    c.drawCircle(
      Offset(x, h * .87),
      h * .055,
      Paint()..color = const Color(0xFFC9CBDD),
    );
  }
  c.restore();
}

/// Small exhaust puff behind a moving bus.
void paintPuff(Canvas c, Offset p, double r, double t) {
  final paint = Paint()..color = Colors.white.withValues(alpha: .75 * (1 - t));
  c.drawCircle(p + Offset(-r * 1.4 * t, -r * .3 * t), r * (1 + t), paint);
  c.drawCircle(
    p + Offset(-r * .6 - r * 2 * t, r * .2),
    r * .7 * (1 + t),
    paint,
  );
}

/// Result illustration: a full bus leaving, or a jammed slot row.
class ResultArtPainter extends CustomPainter {
  const ResultArtPainter(this.won);
  final bool won;
  @override
  void paint(Canvas c, Size s) {
    final h = s.height;
    if (won) {
      final w = min(s.width * .7, h * 1.9);
      paintCoach(
        c,
        Rect.fromCenter(
          center: Offset(s.width / 2, h * .5),
          width: w,
          height: w * .5,
        ),
        BusColor.gold,
        seated: busCapacity,
      );
      paintPuff(c, Offset(s.width / 2 - w * .5, h * .72), h * .06, .3);
    } else {
      final size = min(h * .5, s.width / 6.4);
      for (int i = 0; i < 5; i++) {
        final r = Rect.fromLTWH(
          s.width / 2 - size * 2.8 + i * size * 1.15,
          h * .4,
          size,
          size,
        );
        rr(c, r, Colors.white, size * .2);
        c.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(size * .2)),
          Paint()
            ..color = const Color(0xFFF2583F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        paintRider(
          c,
          Offset(r.center.dx, r.bottom - size * .1),
          size * .9,
          busColors[(i * 2 + 1) % busColors.length],
          arms: i == 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ResultArtPainter old) => won != old.won;
}
