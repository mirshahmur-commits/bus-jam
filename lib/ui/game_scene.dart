import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/controller.dart';
import '../game/model.dart';
import 'art.dart';

/// Geometry of the arena: road with buses, waiting slots, then the crowd.
class SceneLayout {
  SceneLayout(this.size, this.level, this.slots);
  final Size size;
  final Level level;
  final int slots;
  double get roadH => (size.height * .23).clamp(84.0, 150.0);
  Rect get busRect {
    final w = min(size.width * .58, roadH * 2.1);
    final h = w * .46;
    return Rect.fromLTWH(size.width * .5 - w * .42, roadH * .5 - h * .45, w, h);
  }

  /// Where the next bus waits, peeking in from the left edge.
  Rect get queuedBus =>
      busRect.shift(Offset(-busRect.right + size.width * .2, 0));
  Rect get leftBus => busRect.shift(Offset(size.width - busRect.left + 20, 0));
  Offset seat(Rect bus, int seat) => Offset(
    bus.left + bus.width * (.24 + seat * .22),
    bus.top + bus.height * .4,
  );
  Offset get door => Offset(busRect.left + busRect.width * .5, roadH - 6);
  double get slotSize =>
      min(min(52, roadH * .42), (size.width - 32) / (max(slots, 5) + 1.4));
  double get slotY => roadH + 12;
  Rect slot(int i) {
    final gap = slotSize * .18;
    final total = slots * slotSize + (slots - 1) * gap;
    return Rect.fromLTWH(
      size.width / 2 - total / 2 + i * (slotSize + gap),
      slotY,
      slotSize,
      slotSize,
    );
  }

  double get crowdTop => slotY + slotSize + min(30, roadH * .22);

  /// Row height; columns may be a little wider for easier taps.
  double get cell => min(
    (size.height - crowdTop - 14) / level.rows,
    (size.width - 40) / level.cols,
  ).clamp(18.0, 84.0);
  double get cellW => min((size.width - 40) / level.cols, cell * 1.35);
  Rect get plaza {
    final w = cellW * level.cols, h = cell * level.rows;
    final spare = max(0.0, size.height - crowdTop - 14 - h);
    return Rect.fromLTWH(
      size.width / 2 - w / 2,
      crowdTop + min(spare * .3, 48),
      w,
      h,
    );
  }

  Rect cellRect(int i) => Rect.fromLTWH(
    plaza.left + (i % level.cols) * cellW,
    plaza.top + (i ~/ level.cols) * cell,
    cellW,
    cell,
  );

  /// Feet position of a standing passenger in a cell.
  Offset feet(int i) {
    final r = cellRect(i);
    return Offset(r.center.dx, r.bottom - r.height * .1);
  }

  Offset slotFeet(int i) {
    final r = slot(i);
    return Offset(r.center.dx, r.bottom - r.height * .12);
  }

  Offset get gate => Offset(size.width / 2, slotY + slotSize + 14);

  static double heightFor(double width, Level level) {
    final rough = SceneLayout(Size(width, 640), level, level.slots + 1);
    final cell = min((width - 40) / level.cols, 62.0);
    return rough.crowdTop + cell * level.rows + 20;
  }
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
    this.hidden = false,
  });
  final List<Offset> points;
  final BusColor color;
  final int start, duration, bus, seat, slot;
  final bool hidden;
  bool done(int now) => now >= start + duration;
  Offset at(int now) {
    final t = ((now - start) / duration).clamp(0.0, 1.0);
    if (points.length == 1) return points.first;
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

class GameScene extends StatefulWidget {
  const GameScene({
    super.key,
    required this.controller,
    required this.onMove,
    this.onIdle,
  });
  final GameController controller;
  final void Function(MoveResult) onMove;

  /// Called when every walk and bus motion has finished.
  final VoidCallback? onIdle;
  @override
  State<GameScene> createState() => _GameSceneState();
}

class _GameSceneState extends State<GameScene>
    with SingleTickerProviderStateMixin {
  static const busTravel = 420;
  late final Ticker ticker;
  // Scene time advances with frames so tests and devices share one clock.
  int _base = 0, _now = 0;
  final walkers = <SceneWalker>[];
  final departures = <SceneDeparture>[];
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
      if (walkers.isEmpty && departures.isEmpty && t > arrival + busTravel) {
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
      arrival = -100000;
    }
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  void onTap(int cell, SceneLayout scene) {
    final before = c.board;
    final result = c.tap(cell);
    if (!result.accepted) return;
    observed = c.board;
    if (!c.reducedMotion) _animate(before, result, scene);
    widget.onMove(result);
    setState(() {});
  }

  void _animate(Board before, MoveResult result, SceneLayout scene) {
    final t = now;
    final color = BusColor.values[before.people[result.cell]];
    final path = [
      for (final i in result.path) scene.feet(i),
      Offset(
        scene.feet(result.path.last).dx,
        scene.plaza.top - scene.cell * .15,
      ),
      scene.gate,
    ];
    if (result.toBus) {
      path.addAll([scene.door, scene.seat(scene.busRect, before.boarded)]);
    } else {
      path.add(scene.slotFeet(result.waitingSlot));
    }
    final walk = min(720, 160 + result.path.length * 70 + 220);
    walkers.add(
      SceneWalker(
        path,
        color,
        t,
        walk,
        bus: result.toBus ? before.busIndex : -1,
        seat: result.toBus ? before.boarded : -1,
        slot: result.waitingSlot,
        hidden: c.level.hidden.contains(result.cell),
      ),
    );
    if (result.departures > 0) {
      final leave = t + walk;
      departures.add(SceneDeparture(before.busIndex, color, leave));
      arrival = leave + 120;
      final next = result.board;
      // Waiting passengers hop on once the next bus has pulled in.
      for (int k = 0; k < result.fromWaiting.length; k++) {
        final slot = result.fromWaiting[k];
        if (next.busIndex >= c.level.buses.length) break;
        final seat = min(k, busCapacity - 1);
        walkers.add(
          SceneWalker(
            [scene.slotFeet(slot), scene.door, scene.seat(scene.busRect, seat)],
            before.waiting[slot],
            arrival + busTravel + k * 90,
            320,
            bus: next.busIndex,
            seat: seat,
          ),
        );
      }
    }
    if (!ticker.isActive) ticker.start();
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    return LayoutBuilder(
      builder: (context, box) {
        final scene = SceneLayout(box.biggest, c.level, c.board.slots);
        final reach = c.board.phase(c.level) == GamePhase.playing
            ? c.board.reachable(c.level)
            : <int>{};
        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ArenaPainter(
                    scene: scene,
                    level: c.level,
                    board: c.board,
                    reach: c.board.reachable(c.level),
                    hint: c.hintCell,
                    walkers: walkers,
                    departures: departures,
                    arrival: arrival,
                    now: now,
                    skin: c.selectedBus,
                    terminal: c.selectedTerminal,
                  ),
                ),
              ),
            ),
            for (int i = 0; i < c.board.people.length; i++)
              if (c.board.people[i] >= 0)
                Positioned.fromRect(
                  rect: scene.cellRect(i),
                  child: Semantics(
                    button: reach.contains(i),
                    label: c.level.hidden.contains(i) && !reach.contains(i)
                        ? 'Hidden passenger'
                        : '${colorNames[c.board.people[i]]} passenger${reach.contains(i) ? '' : ', blocked'}',
                    child: GestureDetector(
                      key: ValueKey('cell-$i'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i, scene),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class ArenaPainter extends CustomPainter {
  ArenaPainter({
    required this.scene,
    required this.level,
    required this.board,
    required this.reach,
    required this.hint,
    required this.walkers,
    required this.departures,
    required this.arrival,
    required this.now,
    this.skin = 'classic',
    this.terminal = 'terminal-classic',
  });
  final SceneLayout scene;
  final Level level;
  final Board board;
  final Set<int> reach;
  final int? hint;
  final List<SceneWalker> walkers;
  final List<SceneDeparture> departures;
  final int arrival, now;
  final String skin, terminal;

  @override
  void paint(Canvas c, Size s) {
    final pal = ArenaPalette.forId(terminal);
    c.drawRect(Offset.zero & s, Paint()..color = pal.sky);
    // Road and curb.
    c.drawRect(
      Rect.fromLTWH(0, scene.roadH * .12, s.width, scene.roadH * .88),
      Paint()..color = pal.road,
    );
    c.drawRect(
      Rect.fromLTWH(0, scene.roadH * .14, s.width, 5),
      Paint()..color = pal.curb,
    );
    // Stop paving with the waiting slots.
    c.drawRect(
      Rect.fromLTWH(0, scene.roadH - 4, s.width, scene.slotSize + 34),
      Paint()..color = pal.tile,
    );
    c.drawRect(
      Rect.fromLTWH(0, scene.roadH - 4, s.width, 4),
      Paint()..color = pal.curb,
    );
    // Walkway from the crowd to the stop.
    final plaza = scene.plaza;
    rr(
      c,
      Rect.fromLTRB(
        s.width / 2 - scene.cell * .9,
        scene.roadH,
        s.width / 2 + scene.cell * .9,
        plaza.top + 8,
      ),
      pal.tile,
      0,
    );
    rr(c, plaza.inflate(9), pal.curb, 18);
    rr(c, plaza.inflate(4), pal.plaza, 14);
    for (int i = 0; i < level.cells.length; i++) {
      rr(c, scene.cellRect(i).deflate(2.5), pal.tile.withValues(alpha: .55), 8);
    }

    _buses(c, s);

    // Waiting slots.
    final pendingSlots = {
      for (final w in walkers)
        if (w.slot >= 0 && !w.done(now)) w.slot,
    };
    final boarding = {
      for (final w in walkers)
        if (w.bus >= 0 && w.slot < 0 && w.points.length == 3 && now < w.start)
          w.points.first,
    };
    for (int i = 0; i < board.slots; i++) {
      final r = scene.slot(i);
      rr(
        c,
        r.shift(const Offset(0, 3)),
        Colors.black.withValues(alpha: .08),
        10,
      );
      rr(c, r, Colors.white, 10);
      if (i >= board.slots - 1 && board.continued) {
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(10)),
          Paint()
            ..color = const Color(0xFFF6C657)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
    for (int i = 0; i < board.waiting.length; i++) {
      if (pendingSlots.contains(i)) continue;
      paintRider(
        c,
        scene.slotFeet(i),
        scene.slotSize * .78,
        busColors[board.waiting[i].index],
        mark: board.waiting[i].index,
      );
    }
    // Passengers who already left a slot but wait for the bus to arrive.
    for (final p in boarding) {
      final w = walkers.firstWhere((w) => w.points.first == p);
      paintRider(c, p, scene.slotSize * .78, busColors[w.color.index]);
    }

    // Crowd, back rows first so heads overlap naturally.
    final size = scene.cell * .82;
    for (int i = 0; i < board.people.length; i++) {
      final color = board.people[i];
      if (color < 0) continue;
      final open = reach.contains(i);
      final secret = level.hidden.contains(i) && !open;
      if (hint == i) {
        final pulse = 1 + .08 * sin(now / 120);
        c.drawCircle(
          scene.cellRect(i).center,
          scene.cell * .48 * pulse,
          Paint()..color = const Color(0xFFFFE07A).withValues(alpha: .8),
        );
      }
      paintRider(
        c,
        scene.feet(i),
        size,
        busColors[color],
        hidden: secret,
        dim: !open,
        mark: open ? color : null,
      );
    }

    // Walking passengers on top.
    for (final w in walkers) {
      if (now < w.start || w.done(now)) continue;
      final t = (now - w.start) / w.duration;
      paintRider(
        c,
        w.at(now),
        size * (1 - .25 * t),
        busColors[w.color.index],
        mark: w.color.index,
        lift: 3 * sin(t * pi * 6).abs(),
        arms: true,
      );
    }
  }

  void _buses(Canvas c, Size s) {
    final stop = scene.busRect;
    // Seats a walker is still heading for stay empty until arrival.
    Set<int> emptySeats(int bus) => {
      for (final w in walkers)
        if (w.bus == bus && !w.done(now)) w.seat,
    };
    // Next buses wait at the left edge.
    final queued = board.busIndex + 1;
    if (queued < level.buses.length) {
      paintCoach(c, scene.queuedBus, level.buses[queued], skin: skin);
    }
    for (final d in departures) {
      final t = ((now - d.start) / 420).clamp(0.0, 1.0);
      final rect = Rect.lerp(stop, scene.leftBus, Curves.easeIn.transform(t))!;
      paintCoach(
        c,
        rect,
        level.buses[d.bus],
        seated: busCapacity,
        skin: skin,
        emptySeats: emptySeats(d.bus),
      );
    }
    final current = board.currentBus(level);
    if (current != null) {
      final t = ((now - arrival) / 420).clamp(0.0, 1.0);
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
    }
  }

  @override
  bool shouldRepaint(ArenaPainter old) => true;
}
