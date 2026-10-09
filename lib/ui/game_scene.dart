import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/controller.dart';
import '../game/model.dart';
import 'art.dart';

class SceneLayout {
  SceneLayout(this.size, this.lanes, this.slots, {this.maxDepth = 5});
  final Size size;
  final int lanes, slots;
  final int maxDepth;
  double get busW => max(32, min(86, (size.width - 28) / max(lanes, slots) - 10));
  double get busH => busW * 1.48;
  double get parkY => 20;
  double get depotY => parkY + busH + 66;
  Rect slot(int i) => Rect.fromLTWH(
    20 + (size.width - 40) / slots * (i + .5) - busW / 2,
    parkY,
    busW,
    busH,
  );
  Rect depot(int lane, int depth) => Rect.fromLTWH(
    20 + (size.width - 40) / lanes * (lane + .5) - busW / 2,
    depotY + depth * 35,
    busW,
    busH,
  );
  Offset person(int i) => Offset(31 + i * (size.width - 62) / 8, queueY + 26);
  double get queueY => depotY + max(4, maxDepth - 1) * 35 + busH + 24;
  Map<int, Rect> positions(Board board) => {
    for (int i = 0; i < board.parked.length; i++) board.parked[i].id: slot(i),
    for (int lane = 0; lane < board.lanes.length; lane++)
      for (int depth = 0; depth < board.lanes[lane].length; depth++)
        board.lanes[lane][depth].id: depot(lane, depth),
  };
  static double heightFor(double width, Level level) {
    final layout = SceneLayout(Size(width, 0), level.lanes.length, level.slots,
        maxDepth: level.lanes.map((lane) => lane.length).fold(1, max));
    return layout.queueY + 86;
  }
}

class _Motion {
  const _Motion(this.from, this.to, this.start);
  final Rect from, to;
  final int start;
  Rect at(int now) => Rect.lerp(
    from,
    to,
    Curves.easeOutCubic.transform(((now - start) / 260).clamp(0.0, 1.0)),
  )!;
  bool done(int now) => now - start >= 260;
}

class BusDeparture {
  const BusDeparture(this.bus, this.from, this.parking, this.start);
  final Bus bus;
  final Rect from, parking;
  final int start;
  Rect at(int now, double width) {
    final p = ((now - start) / 440).clamp(0.0, 1.0);
    if (p < .43) {
      return Rect.lerp(from, parking, Curves.easeOutCubic.transform(p / .43))!;
    }
    return parking.shift(
      Offset(Curves.easeInCubic.transform((p - .43) / .57) * (width + 100), 0),
    );
  }

  bool done(int now) => now - start >= 440;
}

class PassengerFlight {
  const PassengerFlight(this.color, this.from, this.to, this.start);
  final BusColor color;
  final Offset from, to;
  final int start;
  double progress(int now) => ((now - start) / 220).clamp(0.0, 1.0);
  bool done(int now) => now - start >= 220;
}

class GameScene extends StatefulWidget {
  const GameScene({super.key, required this.controller, required this.onMove});
  final GameController controller;
  final void Function(MoveResult) onMove;
  @override
  State<GameScene> createState() => _GameSceneState();
}

/// Each entity keeps its own motion. Input is never gated on an animation.
/// Retargeting starts from the current rendered position, including rapid taps.
class _GameSceneState extends State<GameScene>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  late Board observed;
  SceneLayout? layout;
  final motions = <int, _Motion>{};
  final departures = <BusDeparture>[];
  final flights = <PassengerFlight>[];
  int now = 0, epoch = 0;
  int? pressedLane;

  @override
  void initState() {
    super.initState();
    observed = widget.controller.board;
    ticker = createTicker((elapsed) {
      setState(() {
        now = epoch + elapsed.inMilliseconds;
        motions.removeWhere((id, motion) => motion.done(now));
        departures.removeWhere((departure) => departure.done(now));
        flights.removeWhere((flight) => flight.done(now));
      });
      if (motions.isEmpty && departures.isEmpty && flights.isEmpty) {
        ticker.stop();
      }
    });
  }

  @override
  void didUpdateWidget(covariant GameScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (observed != widget.controller.board ||
        widget.controller.reducedMotion) {
      motions.clear();
      departures.clear();
      flights.clear();
      ticker.stop();
      observed = widget.controller.board;
    }
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  void release(int lane, int expectedBusId) {
    final c = widget.controller, scene = layout;
    if (scene == null || c.busy) return;
    final old = c.board, oldPositions = scene.positions(c.board);
    final result = c.release(lane, expectedBusId: expectedBusId);
    if (!result.accepted) return;
    observed = result.board;
    setState(() {
      pressedLane = null;
      if (!c.reducedMotion) {
        final destinations = scene.positions(result.board);
        for (final entry in destinations.entries) {
          final from =
              motions[entry.key]?.at(now) ??
              oldPositions[entry.key] ??
              entry.value;
          if (from != entry.value) {
            motions[entry.key] = _Motion(from, entry.value, now);
          }
        }
        for (final bus in result.departures) {
          final oldSlot = old.parked.indexWhere((b) => b.id == bus.id);
          final parking = scene.slot(
            oldSlot >= 0 ? oldSlot : old.parked.length,
          );
          final from =
              motions.remove(bus.id)?.at(now) ??
              oldPositions[bus.id] ??
              parking;
          departures.add(BusDeparture(bus, from, parking, now));
        }
        for (int i = 0; i < min(12, result.boarding.length); i++) {
          final boarding = result.boarding[i];
          final oldSlot = old.parked.indexWhere((b) => b.id == boarding.busId);
          final target =
              destinations[boarding.busId] ??
              scene.slot(oldSlot >= 0 ? oldSlot : old.parked.length);
          flights.add(
            PassengerFlight(
              boarding.color,
              scene.person(min(8, boarding.passenger - old.cursor)),
              target.center,
              now + i * 8,
            ),
          );
        }
        if (!ticker.isActive) {
          epoch = now;
          ticker.start();
        }
      }
    });
    widget.onMove(result);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final c = widget.controller;
      final scene = SceneLayout(
        Size(constraints.maxWidth, constraints.maxHeight),
        c.board.lanes.length,
        c.board.slots,
        maxDepth: c.board.lanes.map((lane) => lane.length).fold(1, max),
      );
      layout = scene;
      final positions = scene
          .positions(c.board)
          .map((id, rect) => MapEntry(id, motions[id]?.at(now) ?? rect));
      return Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: BoardPainter(
                  c.level,
                  c.board,
                  scene,
                  positions: positions,
                  departures: departures,
                  flights: flights,
                  now: now,
                  hint: c.hintLane,
                  pressedLane: pressedLane,
                  skin: c.selectedBus,
                  terminal: c.selectedTerminal,
                ),
              ),
            ),
          ),
          for (int lane = 0; lane < c.board.lanes.length; lane++)
            if (c.board.lanes[lane].isNotEmpty)
              target(scene, lane, c.board.lanes[lane].first),
        ],
      );
    },
  );

  Widget target(SceneLayout scene, int lane, Bus bus) {
    final c = widget.controller;
    return Positioned.fromRect(
      rect: scene.depot(lane, 0).inflate(8),
      child: Semantics(
        label:
            'Release ${colorNames[bus.color.index]} bus, lane ${lane + 1}, ${bus.capacity} seats',
        button: true,
        enabled: c.board.phase(c.level) == GamePhase.playing && !c.busy,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('lane-$lane'),
            borderRadius: BorderRadius.circular(18),
            onTapDown: (_) => setState(() => pressedLane = lane),
            onTapCancel: () => setState(() => pressedLane = null),
            onTap: c.board.phase(c.level) == GamePhase.playing && !c.busy
                ? () => release(lane, bus.id)
                : null,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter(
    this.level,
    this.board,
    this.layout, {
    required this.positions,
    required this.departures,
    required this.flights,
    required this.now,
    this.hint,
    this.pressedLane,
    this.skin = 'classic',
    this.terminal = 'terminal-classic',
  });
  final Level level;
  final Board board;
  final SceneLayout layout;
  final Map<int, Rect> positions;
  final List<BusDeparture> departures;
  final List<PassengerFlight> flights;
  final int now;
  final int? hint, pressedLane;
  final String skin, terminal;

  @override
  void paint(Canvas c, Size size) {
    final palette = TerminalPalette.forId(terminal);
    rr(c, Offset.zero & size, palette.floor, 24);
    rr(
      c,
      Rect.fromLTWH(0, layout.parkY - 12, size.width, layout.busH + 28),
      palette.road,
      0,
    );
    for (int slot = 0; slot < board.slots; slot++) {
      final rect = layout.slot(slot).inflate(4);
      c.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()
          ..color = palette.line.withValues(alpha: .85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      if (slot >= board.parked.length) {
        label(
          c,
          'P',
          rect.center,
          size: 23,
          color: palette.line.withValues(alpha: .5),
        );
      }
    }
    label(
      c,
      '${board.slots - board.parked.length} FREE ${board.slots - board.parked.length == 1 ? 'SPACE' : 'SPACES'}',
      Offset(size.width / 2, layout.parkY + layout.busH + 34),
      size: 10,
      color: board.parked.length >= board.slots - 1
          ? const Color(0xFFCF4438)
          : terminal == 'terminal-night' ? palette.line : ink,
    );
    label(c, 'CHOOSE A BUS', Offset(size.width / 2, layout.depotY - 22),
        size: 12, color: ink);
    for (int lane = 0; lane < board.lanes.length; lane++) {
      final top = layout.depot(lane, 0);
      final bottom = layout.depot(lane, max(0, board.lanes[lane].length - 1));
      rr(
        c,
        Rect.fromLTRB(
          top.left - 7,
          top.top - 8,
          top.right + 7,
          bottom.bottom + 9,
        ),
        palette.road.withValues(alpha: .14),
        15,
      );
      for (int depth = board.lanes[lane].length - 1; depth >= 0; depth--) {
        final bus = board.lanes[lane][depth];
        paintBus(
          c,
          positions[bus.id]!,
          bus,
          opacity: depth == 0 ? 1 : .78,
          highlighted: depth == 0 && (hint == lane || pressedLane == lane),
          skin: skin,
        );
        if (depth > 0) {
          final r = layout.depot(lane, depth);
          rr(c, Rect.fromLTWH(r.right - 6, r.top + 9, 14, 17), ink, 5);
          label(
            c,
            '${bus.capacity}',
            Offset(r.right + 1, r.top + 17),
            size: 10,
            color: Colors.white,
          );
        }
      }
    }
    for (final bus in board.parked) {
      paintBus(c, positions[bus.id]!, bus, skin: skin);
    }
    for (final departure in departures) {
      paintBus(c, departure.at(now, size.width), departure.bus, skin: skin);
    }
    // Passenger queue is visually separated from the bus depot, matching
    // the top-to-bottom parking-jam reading order.
    final queueTop = layout.queueY;
    label(c, 'PASSENGER QUEUE', Offset(size.width / 2, queueTop - 11),
        size: 10, color: ink);
    rr(c, Rect.fromLTWH(9, queueTop, size.width - 18, 66),
        Colors.white.withValues(alpha: .92), 18);
    label(c, '${level.passengers.length - board.cursor} WAITING',
        Offset(size.width - 72, queueTop + 55), size: 9, color: ink);
    for (int i = 0; i < min(9, level.passengers.length - board.cursor); i++) {
      paintPerson(c, layout.person(i), level.passengers[board.cursor + i],
          scale: i == 0 ? .85 : .67);
    }
    if (board.cursor < level.passengers.length) {
      label(c, 'NEXT', Offset(31, queueTop + 57), size: 8, color: teal);
    }
    for (final flight in flights) {
      final p = flight.progress(now);
      if (p <= 0 || p >= 1) continue;
      paintPerson(
        c,
        Offset.lerp(
          flight.from,
          flight.to,
          Curves.easeInOutCubic.transform(p),
        )!,
        flight.color,
        scale: .65 - p * .35,
        bounce: -sin(p * pi) * 14,
      );
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => true;
}
