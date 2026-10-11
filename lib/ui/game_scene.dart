import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/controller.dart';
import '../game/model.dart';
import 'art.dart';

/// Geometry of the arena: road with buses, the stop with waiting slots,
/// then the crowd corridor that streams off the bottom of the screen.
class SceneLayout {
  SceneLayout(this.size, this.level, this.slots, {this.top = 0});
  final Size size;
  final Level level;
  final int slots;

  /// Space reserved for the HUD above the road.
  final double top;
  double get roadH => ((size.height - top) * .24).clamp(96.0, 170.0);
  double get roadTop => top;
  double get roadBottom => roadTop + roadH;
  Rect get busRect {
    final w = min(size.width * .56, roadH * 1.75);
    final h = w * .55;
    return Rect.fromLTWH(
      size.width * .53 - w * .5,
      roadBottom - h - roadH * .06,
      w,
      h,
    );
  }

  /// The next bus waits at the left edge, half on screen.
  Rect get queuedBus =>
      busRect.shift(Offset(-busRect.left - busRect.width * .62, 0));
  Rect get goneBus => busRect.shift(Offset(size.width - busRect.left + 30, 0));
  Offset seat(Rect bus, int seat) => Offset(
    bus.left + bus.width * (.34 + seat * .22),
    bus.top + bus.height * .74,
  );
  Offset get door => Offset(busRect.left + busRect.width * .5, roadBottom + 4);
  double get slotSize =>
      min(min(54, roadH * .44), (size.width - 24) / (max(slots, 5) + 2.6));
  double get slotGap => slotSize * .16;
  double get stopTop => roadBottom;
  double get stopH => slotSize + 26;

  /// Waiting slots plus one lock tile for the extra slot.
  int get tiles => slots + 1;
  Rect slot(int i) {
    final total = tiles * slotSize + (tiles - 1) * slotGap;
    return Rect.fromLTWH(
      size.width / 2 - total / 2 + i * (slotSize + slotGap),
      stopTop + 13,
      slotSize,
      slotSize,
    );
  }

  Rect get lockTile => slot(slots);
  Offset slotFeet(int i) {
    final r = slot(i);
    return Offset(r.center.dx, r.bottom - r.height * .1);
  }

  double get laneW => min(72, (size.width - 48) / level.lanes.length);
  double get rowH => laneW * .6;
  double get corridorTop => stopTop + stopH;
  Rect get corridor {
    final w = laneW * level.lanes.length + 16;
    return Rect.fromLTRB(
      size.width / 2 - w / 2,
      corridorTop - 2,
      size.width / 2 + w / 2,
      size.height + 40,
    );
  }

  double laneX(int lane) => corridor.left + 8 + laneW * (lane + .5);

  /// Feet of the passenger [row] places behind the front of [lane].
  Offset person(int lane, double row) =>
      Offset(laneX(lane), corridorTop + laneW * .95 + rowH * row);
  Rect laneRect(int lane) => Rect.fromLTWH(
    corridor.left + 8 + laneW * lane,
    corridorTop,
    laneW,
    max(0, size.height - corridorTop),
  );
  int get visibleRows => ((size.height - corridorTop) / rowH).ceil() + 1;
  Offset get exit => Offset(size.width / 2, corridorTop - 4);
}

class SceneWalker {
  SceneWalker(
    this.points,
    this.color,
    this.start,
    this.duration, {
    this.bus = -1,
    this.seat = -1,
    this.slot = -1,
    this.fromSlot = -1,
  });
  final List<Offset> points;
  final BusColor color;
  final int start, duration, bus, seat, slot, fromSlot;
  bool done(int now) => now >= start + duration;
  Offset at(int now) {
    final t = ((now - start) / duration).clamp(0.0, 1.0);
    var total = 0.0;
    final lengths = <double>[];
    for (int i = 1; i < points.length; i++) {
      final d = (points[i] - points[i - 1]).distance;
      lengths.add(d);
      total += d;
    }
    var goal = total * Curves.easeInOut.transform(t);
    for (int i = 0; i < lengths.length; i++) {
      if (goal <= lengths[i] || i == lengths.length - 1) {
        final f = lengths[i] == 0 ? 1.0 : (goal / lengths[i]).clamp(0.0, 1.0);
        return Offset.lerp(points[i], points[i + 1], f)!;
      }
      goal -= lengths[i];
    }
    return points.last;
  }
}

class SceneDeparture {
  SceneDeparture(this.bus, this.start);
  final int bus, start;
}

/// Remaining waiting passengers slide left once others have boarded.
class SlotShift {
  SlotShift(this.from, this.start);
  final Map<int, int> from;
  final int start;
}

class GameScene extends StatefulWidget {
  const GameScene({
    super.key,
    required this.controller,
    required this.onMove,
    this.onIdle,
    this.onLockTap,
    this.top = 0,
  });
  final GameController controller;
  final void Function(MoveResult) onMove;

  /// Called when every walk and bus motion has finished.
  final VoidCallback? onIdle;

  /// Called when the locked extra slot is tapped.
  final VoidCallback? onLockTap;
  final double top;
  @override
  State<GameScene> createState() => _GameSceneState();
}

class _GameSceneState extends State<GameScene>
    with SingleTickerProviderStateMixin {
  static const busTravel = 480, step = 230;
  late final Ticker ticker;
  // Scene time advances with frames so tests and devices share one clock.
  int _base = 0, _now = 0;
  final walkers = <SceneWalker>[];
  final departures = <SceneDeparture>[];
  final laneSteps = <int, int>{};
  SlotShift? shift;
  int arrival = -100000;
  late Board observed;
  GameController get c => widget.controller;
  int get now => _now;

  @override
  void initState() {
    super.initState();
    observed = c.board;
    ticker = createTicker((elapsed) {
      _now = _base + elapsed.inMilliseconds;
      final t = now;
      walkers.removeWhere((w) => w.done(t));
      departures.removeWhere((d) => t > d.start + busTravel);
      laneSteps.removeWhere((_, s) => t > s + step);
      if (shift != null && t > shift!.start + step) shift = null;
      if (walkers.isEmpty &&
          departures.isEmpty &&
          laneSteps.isEmpty &&
          shift == null &&
          t > arrival + busTravel) {
        ticker.stop();
        _base = _now;
        widget.onIdle?.call();
      }
      setState(() {});
    });
  }

  void _sync() {
    // Undo, restart and level changes replace the board without a tap.
    if (!identical(observed, c.board)) {
      observed = c.board;
      walkers.clear();
      departures.clear();
      laneSteps.clear();
      shift = null;
      arrival = -100000;
    }
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  void onTap(int lane, SceneLayout scene) {
    final before = c.board;
    final result = c.tap(lane);
    if (!result.accepted) return;
    observed = c.board;
    if (!c.reducedMotion) _animate(before, result, scene);
    widget.onMove(result);
    setState(() {});
  }

  void _animate(Board before, MoveResult result, SceneLayout scene) {
    final t = now;
    final start = scene.person(result.lane, 0);
    final path = [
      start,
      Offset(start.dx, scene.corridorTop + scene.rowH * .2),
      scene.exit,
    ];
    if (result.toBus) {
      path.addAll([scene.door, scene.seat(scene.busRect, result.seat)]);
    } else {
      path.add(scene.slotFeet(result.waitingSlot));
    }
    var length = 0.0;
    for (int i = 1; i < path.length; i++) {
      length += (path[i] - path[i - 1]).distance;
    }
    final walk = (length * 1.6).clamp(260.0, 700.0).round();
    laneSteps[result.lane] = t;
    walkers.add(
      SceneWalker(
        path,
        result.color!,
        t,
        walk,
        bus: result.toBus ? before.busIndex : -1,
        seat: result.seat,
        slot: result.waitingSlot,
      ),
    );
    if (result.departures > 0) {
      final leave = t + walk + 60;
      departures.add(SceneDeparture(before.busIndex, leave));
      arrival = leave + 140;
      final next = result.board;
      // Waiting passengers board by themselves once their bus has pulled in.
      final landed = arrival + busTravel;
      for (int k = 0; k < result.fromWaiting.length; k++) {
        final slot = result.fromWaiting[k];
        final seat = min(k, busCapacity - 1);
        walkers.add(
          SceneWalker(
            [scene.slotFeet(slot), scene.door, scene.seat(scene.busRect, seat)],
            before.waiting[slot],
            landed + k * 110,
            360,
            bus: next.busIndex,
            seat: seat,
            fromSlot: slot,
          ),
        );
      }
      if (result.fromWaiting.isNotEmpty) {
        final kept = [
          for (int i = 0; i < before.waiting.length; i++)
            if (!result.fromWaiting.contains(i)) i,
        ];
        shift = SlotShift({
          for (int k = 0; k < kept.length; k++) k: kept[k],
        }, landed + result.fromWaiting.length * 110 + 200);
      }
    }
    if (!ticker.isActive) ticker.start();
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    return LayoutBuilder(
      builder: (context, box) {
        final scene = SceneLayout(
          box.biggest,
          c.level,
          c.board.slots,
          top: widget.top,
        );
        final playing = c.board.phase(c.level) == GamePhase.playing;
        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ArenaPainter(
                    scene: scene,
                    level: c.level,
                    board: c.board,
                    hint: c.hintLane,
                    walkers: walkers,
                    departures: departures,
                    laneSteps: laneSteps,
                    shift: shift,
                    arrival: arrival,
                    now: now,
                    skin: c.selectedBus,
                    terminal: c.selectedTerminal,
                    lockOpen: !c.board.continued,
                  ),
                ),
              ),
            ),
            for (int lane = 0; lane < c.level.lanes.length; lane++)
              Positioned.fromRect(
                rect: scene.laneRect(lane),
                child: Semantics(
                  button: playing && c.board.open(c.level, lane),
                  label: _laneLabel(lane),
                  child: GestureDetector(
                    key: ValueKey('lane-$lane'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(lane, scene),
                  ),
                ),
              ),
            if (!c.board.continued)
              Positioned.fromRect(
                rect: scene.lockTile,
                child: Semantics(
                  button: true,
                  label: 'Unlock an extra waiting slot',
                  child: GestureDetector(
                    key: const ValueKey('lock-slot'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onLockTap,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _laneLabel(int lane) {
    final front = c.board.front(c.level, lane);
    if (front == null) return 'Empty lane';
    final left = c.level.lanes[lane].length - c.board.taken[lane];
    return 'Lane ${lane + 1}: ${colorNames[front]} passenger in front, $left in line';
  }
}

class ArenaPainter extends CustomPainter {
  ArenaPainter({
    required this.scene,
    required this.level,
    required this.board,
    required this.hint,
    required this.walkers,
    required this.departures,
    required this.laneSteps,
    required this.shift,
    required this.arrival,
    required this.now,
    this.skin = 'classic',
    this.terminal = 'terminal-classic',
    this.lockOpen = true,
  });
  final SceneLayout scene;
  final Level level;
  final Board board;
  final int? hint;
  final List<SceneWalker> walkers;
  final List<SceneDeparture> departures;
  final Map<int, int> laneSteps;
  final SlotShift? shift;
  final int arrival, now;
  final String skin, terminal;
  final bool lockOpen;

  @override
  void paint(Canvas c, Size s) {
    final pal = ArenaPalette.forId(terminal);
    c.drawRect(Offset.zero & s, Paint()..color = pal.ground);
    final kerb = scene.roadTop + scene.roadH * .3;
    c.drawRect(Rect.fromLTWH(0, 0, s.width, kerb), Paint()..color = pal.sky);
    c.drawRect(
      Rect.fromLTWH(0, kerb, s.width, scene.roadBottom - kerb),
      Paint()..color = pal.road,
    );
    c.drawRect(
      Rect.fromLTWH(0, kerb - 3, s.width, 6),
      Paint()..color = pal.curb,
    );
    c.drawRect(
      Rect.fromLTWH(0, scene.stopTop, s.width, scene.stopH),
      Paint()..color = pal.stop,
    );
    c.drawRect(
      Rect.fromLTWH(0, scene.stopTop, s.width, 3),
      Paint()..color = pal.curb.withValues(alpha: .9),
    );
    _corridor(c, s, pal);
    _buses(c);
    _slots(c);
    _crowd(c, s);
    for (final w in walkers) {
      if (now < w.start || w.done(now)) continue;
      final t = (now - w.start) / w.duration;
      paintRider(
        c,
        w.at(now) - Offset(0, 6 * sin(t * pi * 5).abs()),
        scene.laneW * .9 * (1 - .25 * t),
        busColors[w.color.index],
        mark: w.color.index,
        arms: true,
      );
    }
  }

  void _corridor(Canvas c, Size s, ArenaPalette pal) {
    final box = scene.corridor;
    final outer = RRect.fromRectAndCorners(
      box.inflate(7),
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
    );
    c.drawRRect(
      outer.shift(const Offset(0, 4)),
      Paint()..color = Colors.black.withValues(alpha: .08),
    );
    c.drawRRect(outer, Paint()..color = pal.curb);
    c.drawRRect(
      RRect.fromRectAndCorners(
        box,
        topLeft: const Radius.circular(13),
        topRight: const Radius.circular(13),
      ),
      Paint()..color = pal.corridor,
    );
    // Neck joining the corridor to the stop.
    rr(
      c,
      Rect.fromLTRB(
        s.width / 2 - scene.laneW * .7,
        scene.stopTop + scene.stopH - 10,
        s.width / 2 + scene.laneW * .7,
        box.top + 8,
      ),
      pal.corridor,
      6,
    );
    final line = Paint()
      ..color = pal.ground.withValues(alpha: .35)
      ..strokeWidth = 1.5;
    for (int lane = 1; lane < level.lanes.length; lane++) {
      final x = box.left + 8 + scene.laneW * lane;
      for (double y = box.top + 14; y < s.height; y += 16) {
        c.drawLine(Offset(x, y), Offset(x, y + 7), line);
      }
    }
  }

  void _crowd(Canvas c, Size s) {
    final size = scene.laneW * .9;
    final playing = board.phase(level) == GamePhase.playing;
    // Front rows first: rows nearer the bottom overlap those ahead of them.
    for (int row = 0; row < scene.visibleRows; row++) {
      for (int lane = 0; lane < level.lanes.length; lane++) {
        final depth = board.taken[lane] + row;
        if (depth >= level.lanes[lane].length) continue;
        final stepped = laneSteps[lane];
        final lag = stepped == null
            ? 0.0
            : 1 -
                  Curves.easeOut.transform(
                    ((now - stepped) / 230).clamp(0.0, 1.0),
                  );
        final p = scene.person(lane, row + lag);
        if (p.dy - size > s.height) continue;
        final color = level.lanes[lane][depth];
        final secret = row > 0 && level.isHidden(lane, depth);
        if (row == 0 && hint == lane && playing) {
          final pulse = 1 + .1 * sin(now / 110);
          c.drawOval(
            Rect.fromCenter(
              center: p,
              width: size * .95 * pulse,
              height: size * .36 * pulse,
            ),
            Paint()..color = const Color(0xFFFFE07A),
          );
          _arrow(c, p - Offset(0, size * 1.22 + 4 * sin(now / 140)), size);
        }
        paintRider(
          c,
          p,
          size,
          busColors[color],
          hidden: secret,
          mark: row == 0 ? color : null,
        );
      }
    }
  }

  void _arrow(Canvas c, Offset tip, double size) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - size * .2, tip.dy - size * .2)
      ..lineTo(tip.dx + size * .2, tip.dy - size * .2)
      ..close();
    c.drawPath(path, Paint()..color = const Color(0xFFFFC93C));
  }

  void _slots(Canvas c) {
    final radius = Radius.circular(scene.slotSize * .2);
    for (int i = 0; i < board.slots; i++) {
      final r = scene.slot(i);
      c.drawRRect(
        RRect.fromRectAndRadius(r.shift(const Offset(0, 3)), radius),
        Paint()..color = Colors.black.withValues(alpha: .1),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(r, radius),
        Paint()..color = Colors.white,
      );
      if (board.continued && i == board.slots - 1) {
        c.drawRRect(
          RRect.fromRectAndRadius(r, radius),
          Paint()
            ..color = const Color(0xFFFFC93C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
    if (lockOpen) _lock(c, scene.lockTile, radius);
    final arriving = {
      for (final w in walkers)
        if (w.slot >= 0 && !w.done(now)) w.slot,
    };
    for (int i = 0; i < board.waiting.length; i++) {
      if (arriving.contains(i)) continue;
      var p = scene.slotFeet(i);
      final from = shift?.from[i];
      if (from != null) {
        final t = ((now - shift!.start) / 230).clamp(0.0, 1.0);
        p = Offset.lerp(scene.slotFeet(from), p, Curves.easeOut.transform(t))!;
      }
      paintRider(
        c,
        p,
        scene.slotSize * .8,
        busColors[board.waiting[i].index],
        mark: board.waiting[i].index,
      );
    }
    // Passengers who will hop on once their bus has pulled in.
    for (final w in walkers) {
      if (w.fromSlot < 0 || now >= w.start) continue;
      paintRider(
        c,
        w.points.first,
        scene.slotSize * .8,
        busColors[w.color.index],
        mark: w.color.index,
      );
    }
  }

  void _lock(Canvas c, Rect r, Radius radius) {
    c.drawRRect(
      RRect.fromRectAndRadius(r.shift(const Offset(0, 3)), radius),
      Paint()..color = const Color(0xFF6E3FB8),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, radius),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC77DFF), Color(0xFF9B4DE8)],
        ).createShader(r),
    );
    final body = Rect.fromCenter(
      center: r.center + Offset(0, -r.height * .06),
      width: r.width * .36,
      height: r.height * .26,
    );
    c.drawArc(
      Rect.fromCenter(
        center: body.topCenter,
        width: body.width * .7,
        height: body.height * 1.3,
      ),
      pi,
      pi,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width * .07,
    );
    rr(c, body, Colors.white, 3);
    label(
      c,
      '+1',
      Offset(r.center.dx, r.bottom - r.height * .17),
      size: r.height * .2,
      color: Colors.white,
      weight: FontWeight.w900,
    );
  }

  void _buses(Canvas c) {
    final stop = scene.busRect;
    // Seats a passenger is still heading for stay empty until arrival.
    Set<int> emptySeats(int bus) => {
      for (final w in walkers)
        if (w.bus == bus && !w.done(now)) w.seat,
    };
    final queued = board.busIndex + 1;
    if (queued < level.buses.length) {
      paintCoach(c, scene.queuedBus, level.buses[queued], skin: skin);
    }
    for (final d in departures) {
      final t = ((now - d.start) / 480).clamp(0.0, 1.0);
      final rect = Rect.lerp(stop, scene.goneBus, Curves.easeIn.transform(t))!;
      paintCoach(
        c,
        rect,
        level.buses[d.bus],
        seated: busCapacity,
        skin: skin,
        emptySeats: emptySeats(d.bus),
      );
      if (t > 0) {
        paintPuff(
          c,
          Offset(rect.left, rect.top + rect.height * .8),
          rect.height * .08,
          t,
        );
      }
    }
    final current = board.currentBus(level);
    if (current != null) {
      final t = ((now - arrival) / 480).clamp(0.0, 1.0);
      final rect = Rect.lerp(
        scene.queuedBus,
        stop,
        Curves.easeOutBack.transform(t),
      )!;
      paintCoach(
        c,
        rect,
        current,
        seated: board.boarded,
        skin: skin,
        emptySeats: emptySeats(board.busIndex),
      );
      if (t > 0 && t < 1) {
        paintPuff(
          c,
          Offset(rect.left, rect.top + rect.height * .8),
          rect.height * .08,
          t,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ArenaPainter old) => true;
}
