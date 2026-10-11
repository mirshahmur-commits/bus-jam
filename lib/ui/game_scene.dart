import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/controller.dart';
import '../game/model.dart';
import 'art.dart';

/// What the arena shows: shared by puzzle levels and the endless rush.
class ArenaView {
  const ArenaView({
    required this.lanes,
    required this.waiting,
    required this.slots,
    required this.current,
    required this.boarded,
    required this.busSerial,
    this.next,
    this.capacity = busCapacity,
    this.continued = false,
    this.lockOpen = true,
    this.playing = true,
    this.hint,
    this.rainbow = false,
    this.skin = 'classic',
    this.terminal = 'terminal-classic',
  });

  /// Passenger colours per lane, front first; -1 marks a hidden passenger.
  final List<List<int>> lanes;
  final List<BusColor> waiting;
  final int slots, boarded, capacity;

  /// Running number of the bus at the stop, for motion bookkeeping.
  final int busSerial;
  final BusColor? current, next;
  final bool continued, lockOpen, playing, rainbow;
  final int? hint;
  final String skin, terminal;
}

/// Geometry of the arena: road with buses, the stop with waiting slots,
/// then the crowd corridor that streams off the bottom of the screen.
class SceneLayout {
  SceneLayout(
    this.size,
    this.laneCount,
    this.slots, {
    this.top = 0,
    this.capacity = busCapacity,
  });
  final Size size;
  final int laneCount, slots, capacity;

  /// Space reserved for the HUD above the road.
  final double top;
  double get roadH => ((size.height - top) * .24).clamp(96.0, 170.0);
  double get roadTop => top;
  double get roadBottom => roadTop + roadH;
  Rect get busRect {
    final grow = 1 + (capacity - busCapacity) * .1;
    final w = min(size.width * .56 * grow, roadH * 1.75 * grow);
    final h = min(w, roadH * 1.75) * .55;
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
    bus.left +
        bus.width *
            (coachSeat(seat, capacity) + coachSeatWidth(capacity) * .55),
    bus.top + bus.height * .8,
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

  double get laneW => min(72, (size.width - 48) / laneCount);
  double get rowH => laneW * .6;
  double get corridorTop => stopTop + stopH;
  Rect get corridor {
    final w = laneW * laneCount + 16;
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
  SceneDeparture(this.bus, this.color, this.start);
  final int bus, start;
  final BusColor color;
}

/// Remaining waiting passengers slide left once others have boarded.
class SlotShift {
  SlotShift(this.from, this.start);
  final Map<int, int> from;
  final int start;
}

/// Motion state shared by the puzzle and rush scenes. Motion is purely
/// cosmetic: the rules have already moved on when it starts.
class SceneMotion {
  static const busTravel = 480, step = 230, arrive = 420;
  final walkers = <SceneWalker>[];
  final departures = <SceneDeparture>[];
  final laneSteps = <int, int>{};
  final arrivals = <int, int>{};
  SlotShift? shift;
  int arrival = -100000;
  bool get idle =>
      walkers.isEmpty &&
      departures.isEmpty &&
      laneSteps.isEmpty &&
      arrivals.isEmpty &&
      shift == null;
  void clear() {
    walkers.clear();
    departures.clear();
    laneSteps.clear();
    arrivals.clear();
    shift = null;
    arrival = -100000;
  }

  /// Drops finished motion; returns true while anything still moves.
  bool prune(int t) {
    walkers.removeWhere((w) => w.done(t));
    departures.removeWhere((d) => t > d.start + busTravel);
    laneSteps.removeWhere((_, s) => t > s + step);
    arrivals.removeWhere((_, s) => t > s + arrive);
    if (shift != null && t > shift!.start + step) shift = null;
    return !idle || t <= arrival + busTravel;
  }

  /// Animates a passenger leaving [lane] for the bus or a waiting slot,
  /// then any departures and waiting passengers hopping on afterwards.
  void move({
    required SceneLayout scene,
    required int now,
    required int lane,
    required BusColor color,
    required bool toBus,
    required int seat,
    required int slot,
    required int busSerial,
    required List<BusColor> waitingBefore,
    required List<int> fromWaiting,
    required List<BusColor> departed,
  }) {
    final t = now;
    final path = <Offset>[];
    if (lane >= 0) {
      final start = scene.person(lane, 0);
      path.addAll([
        start,
        Offset(start.dx, scene.corridorTop + scene.rowH * .2),
        scene.exit,
      ]);
      laneSteps[lane] = t;
    }
    var walk = 0;
    if (path.isNotEmpty) {
      if (toBus) {
        path.addAll([scene.door, scene.seat(scene.busRect, seat)]);
      } else {
        path.add(scene.slotFeet(slot));
      }
      var length = 0.0;
      for (int i = 1; i < path.length; i++) {
        length += (path[i] - path[i - 1]).distance;
      }
      walk = (length * 1.6).clamp(260.0, 700.0).round();
      walkers.add(
        SceneWalker(
          path,
          color,
          t,
          walk,
          bus: toBus ? busSerial : -1,
          seat: seat,
          slot: slot,
        ),
      );
    }
    var serial = busSerial;
    var landed = t;
    if (departed.isNotEmpty) {
      final leave = t + walk + 60;
      departures.add(SceneDeparture(busSerial, departed.first, leave));
      serial += departed.length;
      arrival = leave + 140;
      landed = arrival + busTravel;
    }
    // Waiting passengers board by themselves once their bus is at the stop.
    for (int k = 0; k < fromWaiting.length; k++) {
      final from = fromWaiting[k];
      final s = min(k, scene.capacity - 1);
      walkers.add(
        SceneWalker(
          [scene.slotFeet(from), scene.door, scene.seat(scene.busRect, s)],
          waitingBefore[from],
          landed + k * 110,
          360,
          bus: serial,
          seat: s,
          fromSlot: from,
        ),
      );
    }
    if (fromWaiting.isNotEmpty) {
      final kept = [
        for (int i = 0; i < waitingBefore.length; i++)
          if (!fromWaiting.contains(i)) i,
      ];
      shift = SlotShift({
        for (int k = 0; k < kept.length; k++) k: kept[k],
      }, landed + fromWaiting.length * 110 + 200);
    }
  }
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
  late final Ticker ticker;
  // Scene time advances with frames so tests and devices share one clock.
  int _base = 0, _now = 0;
  final motion = SceneMotion();
  late Board observed;
  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    observed = c.board;
    ticker = createTicker((elapsed) {
      _now = _base + elapsed.inMilliseconds;
      if (!motion.prune(_now)) {
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
      motion.clear();
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
    if (!c.reducedMotion) {
      motion.move(
        scene: scene,
        now: _now,
        lane: result.lane,
        color: result.color!,
        toBus: result.toBus,
        seat: result.seat,
        slot: result.waitingSlot,
        busSerial: before.busIndex,
        waitingBefore: before.waiting,
        fromWaiting: result.fromWaiting,
        departed: [
          for (int k = 0; k < result.departures; k++)
            c.level.buses[before.busIndex + k],
        ],
      );
      if (!ticker.isActive) ticker.start();
    }
    widget.onMove(result);
    setState(() {});
  }

  ArenaView get view {
    final l = c.level, b = c.board;
    return ArenaView(
      lanes: [
        for (int lane = 0; lane < l.lanes.length; lane++)
          [
            for (int d = b.taken[lane]; d < l.lanes[lane].length; d++)
              d > b.taken[lane] && l.isHidden(lane, d) ? -1 : l.lanes[lane][d],
          ],
      ],
      waiting: b.waiting,
      slots: b.slots,
      current: b.currentBus(l),
      next: b.busIndex + 1 < l.buses.length ? l.buses[b.busIndex + 1] : null,
      boarded: b.boarded,
      busSerial: b.busIndex,
      continued: b.continued,
      lockOpen: !b.continued,
      playing: b.phase(l) == GamePhase.playing,
      hint: c.hintLane,
      skin: c.selectedBus,
      terminal: c.selectedTerminal,
    );
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final v = view;
    return LayoutBuilder(
      builder: (context, box) {
        final scene = SceneLayout(
          box.biggest,
          v.lanes.length,
          v.slots,
          top: widget.top,
        );
        return ArenaStack(
          scene: scene,
          view: v,
          motion: motion,
          now: _now,
          laneLabel: _laneLabel,
          onLane: (lane) => onTap(lane, scene),
          onLockTap: widget.onLockTap,
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

/// The painted arena with one tap target per lane and the lock tile.
class ArenaStack extends StatelessWidget {
  const ArenaStack({
    super.key,
    required this.scene,
    required this.view,
    required this.motion,
    required this.now,
    required this.laneLabel,
    required this.onLane,
    this.onLockTap,
  });
  final SceneLayout scene;
  final ArenaView view;
  final SceneMotion motion;
  final int now;
  final String Function(int lane) laneLabel;
  final void Function(int lane) onLane;
  final VoidCallback? onLockTap;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: ArenaPainter(
              scene: scene,
              view: view,
              motion: motion,
              now: now,
            ),
          ),
        ),
      ),
      for (int lane = 0; lane < view.lanes.length; lane++)
        Positioned.fromRect(
          rect: scene.laneRect(lane),
          child: Semantics(
            button: view.playing && view.lanes[lane].isNotEmpty,
            label: laneLabel(lane),
            child: GestureDetector(
              key: ValueKey('lane-$lane'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onLane(lane),
            ),
          ),
        ),
      if (view.lockOpen)
        Positioned.fromRect(
          rect: scene.lockTile,
          child: Semantics(
            button: true,
            label: 'Unlock an extra waiting slot',
            child: GestureDetector(
              key: const ValueKey('lock-slot'),
              behavior: HitTestBehavior.opaque,
              onTap: onLockTap,
            ),
          ),
        ),
    ],
  );
}

class ArenaPainter extends CustomPainter {
  ArenaPainter({
    required this.scene,
    required this.view,
    required this.motion,
    required this.now,
  });
  final SceneLayout scene;
  final ArenaView view;
  final SceneMotion motion;
  final int now;
  String get skin => view.skin;
  String get terminal => view.terminal;
  List<SceneWalker> get walkers => motion.walkers;

  @override
  void paint(Canvas c, Size s) {
    final pal = ArenaPalette.forId(view.terminal);
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
    for (int lane = 1; lane < view.lanes.length; lane++) {
      final x = box.left + 8 + scene.laneW * lane;
      for (double y = box.top + 14; y < s.height; y += 16) {
        c.drawLine(Offset(x, y), Offset(x, y + 7), line);
      }
    }
  }

  void _crowd(Canvas c, Size s) {
    final size = scene.laneW * .9;
    // Front rows first: rows nearer the bottom overlap those ahead of them.
    for (int row = 0; row < scene.visibleRows; row++) {
      for (int lane = 0; lane < view.lanes.length; lane++) {
        final line = view.lanes[lane];
        if (row >= line.length) continue;
        final stepped = motion.laneSteps[lane];
        var lag = stepped == null
            ? 0.0
            : 1 -
                  Curves.easeOut.transform(
                    ((now - stepped) / SceneMotion.step).clamp(0.0, 1.0),
                  );
        // A newcomer walks up from below to the back of the line.
        final came = motion.arrivals[lane];
        if (came != null && row == line.length - 1) {
          lag +=
              2.5 *
              (1 -
                  Curves.easeOut.transform(
                    ((now - came) / SceneMotion.arrive).clamp(0.0, 1.0),
                  ));
        }
        final p = scene.person(lane, row + lag);
        if (p.dy - size > s.height) continue;
        final color = line[row];
        if (row == 0 && view.hint == lane && view.playing) {
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
          busColors[max(color, 0)],
          hidden: color < 0,
          mark: row == 0 && color >= 0 ? color : null,
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
    for (int i = 0; i < view.slots; i++) {
      final r = scene.slot(i);
      c.drawRRect(
        RRect.fromRectAndRadius(r.shift(const Offset(0, 3)), radius),
        Paint()..color = Colors.black.withValues(alpha: .1),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(r, radius),
        Paint()..color = Colors.white,
      );
      if (view.continued && i == view.slots - 1) {
        c.drawRRect(
          RRect.fromRectAndRadius(r, radius),
          Paint()
            ..color = const Color(0xFFFFC93C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
    if (view.lockOpen) _lock(c, scene.lockTile, radius);
    final arriving = {
      for (final w in walkers)
        if (w.slot >= 0 && !w.done(now)) w.slot,
    };
    final shift = motion.shift;
    for (int i = 0; i < view.waiting.length; i++) {
      if (arriving.contains(i)) continue;
      var p = scene.slotFeet(i);
      final from = shift?.from[i];
      if (from != null) {
        final t = ((now - shift!.start) / SceneMotion.step).clamp(0.0, 1.0);
        p = Offset.lerp(scene.slotFeet(from), p, Curves.easeOut.transform(t))!;
      }
      paintRider(
        c,
        p,
        scene.slotSize * .8,
        busColors[view.waiting[i].index],
        mark: view.waiting[i].index,
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
    final next = view.next;
    if (next != null) {
      paintCoach(c, scene.queuedBus, next, capacity: view.capacity, skin: skin);
    }
    for (final d in motion.departures) {
      final t = ((now - d.start) / SceneMotion.busTravel).clamp(0.0, 1.0);
      final rect = Rect.lerp(stop, scene.goneBus, Curves.easeIn.transform(t))!;
      paintCoach(
        c,
        rect,
        d.color,
        seated: view.capacity,
        capacity: view.capacity,
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
    final current = view.current;
    if (current != null) {
      final t = ((now - motion.arrival) / SceneMotion.busTravel).clamp(
        0.0,
        1.0,
      );
      final rect = Rect.lerp(
        scene.queuedBus,
        stop,
        Curves.easeOutBack.transform(t),
      )!;
      paintCoach(
        c,
        rect,
        current,
        seated: view.boarded,
        capacity: view.capacity,
        skin: skin,
        emptySeats: emptySeats(view.busSerial),
        rainbow: view.rainbow,
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
