import 'dart:math';

import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../game/model.dart';
import 'art.dart';

class SceneLayout {
  SceneLayout(this.size, this.lanes, this.slots);
  final Size size;
  final int lanes, slots;
  double get busW => min(70, (size.width - 56) / max(lanes, slots) - 13);
  double get busH => busW * 1.48;
  double get parkY => 95;
  double get depotY => parkY + busH + 85;
  Rect slot(int i) => Rect.fromLTWH(
    18 + (size.width - 36) / slots * (i + .5) - busW / 2,
    parkY,
    busW,
    busH,
  );
  Rect depot(int lane, int depth) => Rect.fromLTWH(
    18 + (size.width - 36) / lanes * (lane + .5) - busW / 2,
    depotY + depth * 34,
    busW,
    busH,
  );
  Offset person(int visible) => Offset(32 + visible * 31, 31);
  Map<int, Rect> positions(Board b) => {
    for (int i = 0; i < b.parked.length; i++) b.parked[i].id: slot(i),
    for (int l = 0; l < b.lanes.length; l++)
      for (int d = 0; d < b.lanes[l].length; d++) b.lanes[l][d].id: depot(l, d),
  };
}

class GameScene extends StatefulWidget {
  const GameScene({super.key, required this.controller, required this.onMove});
  final GameController controller;
  final void Function(MoveResult) onMove;
  @override
  State<GameScene> createState() => _GameSceneState();
}

class _GameSceneState extends State<GameScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  Board? before;
  MoveResult? transition;
  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..value = 1;
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  void release(int lane) {
    if (animation.isAnimating || widget.controller.busy) {
      return;
    }
    final old = widget.controller.board,
        result = widget.controller.release(lane);
    if (!result.accepted) {
      return;
    }
    setState(() {
      before = old;
      transition = result;
    });
    if (widget.controller.reducedMotion) {
      animation.value = 1;
    } else {
      animation.forward(from: 0);
    }
    widget.onMove(result);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return LayoutBuilder(
      builder: (context, con) {
        final layout = SceneLayout(
          Size(con.maxWidth, con.maxHeight),
          c.board.lanes.length,
          c.board.slots,
        );
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final valid = transition?.board == c.board;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: BoardPainter(
                      c.level,
                      c.board,
                      layout,
                      before: valid ? before : null,
                      result: valid ? transition : null,
                      t: valid ? animation.value : 1,
                      hint: c.hintLane,
                    ),
                  ),
                ),
                for (int lane = 0; lane < c.board.lanes.length; lane++)
                  if (c.board.lanes[lane].isNotEmpty)
                    Positioned.fromRect(
                      rect: layout.depot(lane, 0).inflate(9),
                      child: Semantics(
                        label:
                            'Release ${colorNames[c.board.lanes[lane].first.color.index]} bus, lane ${lane + 1}',
                        button: true,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: ValueKey('lane-$lane'),
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => release(lane),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
              ],
            );
          },
        );
      },
    );
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter(
    this.level,
    this.board,
    this.layout, {
    this.before,
    this.result,
    required this.t,
    this.hint,
  });
  final Level level;
  final Board board;
  final SceneLayout layout;
  final Board? before;
  final MoveResult? result;
  final double t;
  final int? hint;

  Rect boardingPosition(int busId) {
    final oldIndex = before?.parked.indexWhere((bus) => bus.id == busId) ?? -1;
    final slot = oldIndex >= 0 ? oldIndex : before?.parked.length ?? 0;
    return layout.slot(slot.clamp(0, board.slots - 1));
  }

  @override
  void paint(Canvas c, Size s) {
    rr(c, Offset.zero & s, const Color(0xFF454F5C), 27);
    rr(c, Rect.fromLTWH(13, 8, s.width - 26, 62), const Color(0xFFDCE2E8), 19);
    final visible = min(9, level.passengers.length - board.cursor);
    for (int i = 0; i < visible; i++) {
      final p = layout.person(i);
      if (p.dx > s.width - 30) {
        break;
      }
      paintPerson(
        c,
        p,
        level.passengers[board.cursor + i],
        scale: i == 0 ? 1 : .82,
      );
    }
    label(
      c,
      '${level.passengers.length - board.cursor} WAITING',
      Offset(s.width / 2, 61),
      size: 9,
      color: ink.withValues(alpha: .5),
    );
    rr(
      c,
      Rect.fromLTWH(0, layout.parkY - 14, s.width, layout.busH + 31),
      const Color(0xFF606D7C),
      0,
    );
    for (int i = 0; i < board.slots; i++) {
      final r = layout.slot(i).inflate(5);
      c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(11)),
        Paint()
          ..color = const Color(0xFFD6DDE3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (i >= board.parked.length) {
        label(
          c,
          'P',
          r.center,
          size: 24,
          color: Colors.white.withValues(alpha: .45),
        );
      }
    }
    label(
      c,
      'BOARDING ZONE  ·  ${board.parked.length}/${board.slots} OCCUPIED',
      Offset(s.width / 2, layout.parkY + layout.busH + 35),
      size: 9,
      color: Colors.white.withValues(alpha: .8),
    );
    label(
      c,
      'TAP A FRONT BUS',
      Offset(s.width / 2, layout.depotY - 22),
      size: 10,
      color: Colors.white.withValues(alpha: .8),
    );
    final now = layout.positions(board),
        prev = before == null
            ? now
            : SceneLayout(
                s,
                before!.lanes.length,
                before!.slots,
              ).positions(before!);
    for (int lane = 0; lane < board.lanes.length; lane++) {
      final count = min(4, board.lanes[lane].length);
      for (int depth = count - 1; depth >= 0; depth--) {
        final b = board.lanes[lane][depth];
        final r = Rect.lerp(
          prev[b.id] ?? now[b.id],
          now[b.id],
          Curves.easeOutCubic.transform(t),
        )!;
        paintBus(
          c,
          r,
          b,
          opacity: depth == 0 ? 1 : max(.45, 1 - depth * .16),
          highlighted: hint == lane && depth == 0,
        );
      }
      if (board.lanes[lane].length > 4) {
        label(
          c,
          '+${board.lanes[lane].length - 4}',
          Offset(layout.depot(lane, 0).center.dx, s.height - 12),
          size: 11,
          color: Colors.white,
        );
      }
    }
    for (final b in board.parked) {
      final destination = now[b.id]!;
      paintBus(
        c,
        Rect.lerp(
          prev[b.id] ?? destination,
          destination,
          Curves.easeOutCubic.transform((t / .35).clamp(0, 1)),
        )!,
        b,
      );
    }
    if (t < 1 && result != null && before != null) {
      for (final b in result!.departures) {
        final parking = boardingPosition(b.id), start = prev[b.id] ?? parking;
        var r = Rect.lerp(
          start,
          parking,
          Curves.easeOutCubic.transform((t / .28).clamp(0, 1)),
        )!;
        if (t > .66) {
          r = r.shift(
            Offset(
              Curves.easeInCubic.transform(((t - .66) / .34).clamp(0, 1)) *
                  (s.width + 100),
              0,
            ),
          );
        }
        paintBus(c, r, b);
      }
      for (int i = 0; i < min(12, result!.boarding.length); i++) {
        final item = result!.boarding[i],
            p = ((t - .2 - i * .018) / .4).clamp(0.0, 1.0);
        if (p <= 0 || p >= 1) {
          continue;
        }
        final target = now[item.busId] ?? boardingPosition(item.busId),
            origin = layout.person(min(8, item.passenger - before!.cursor));
        paintPerson(
          c,
          Offset.lerp(origin, target.center, Curves.easeInOut.transform(p))!,
          item.color,
          scale: 1 - p * .6,
          bounce: -sin(p * pi) * 18,
        );
      }
    }
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}
