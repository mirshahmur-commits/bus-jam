import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/controller.dart';
import '../game/endless.dart';
import '../game/model.dart';
import 'art.dart';
import 'game_scene.dart';

/// Live arena for the endless rush. The frame clock drives arrivals, so the
/// crowd keeps walking while [paused] is false.
class RushScene extends StatefulWidget {
  const RushScene({
    super.key,
    required this.controller,
    this.top = 0,
    this.paused = false,
    this.onMove,
    this.onLockTap,
  });
  final GameController controller;
  final double top;
  final bool paused;
  final void Function(RushMove move)? onMove;
  final VoidCallback? onLockTap;
  @override
  State<RushScene> createState() => RushSceneState();
}

class RushSceneState extends State<RushScene>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  final motion = SceneMotion();
  int _now = 0, _last = 0, _base = 0;
  EndlessRun? _run;
  SceneLayout? _scene;
  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _run = c.rush;
    ticker = createTicker(_frame);
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant RushScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final live = c.rush != null && !c.rush!.over && !widget.paused;
    if (live && !ticker.isActive) {
      _base = _now;
      _last = _now;
      ticker.start();
    } else if (!live && ticker.isActive && motion.idle) {
      ticker.stop();
    }
  }

  void _frame(Duration elapsed) {
    _now = _base + elapsed.inMilliseconds;
    final run = c.rush;
    if (run != null && !run.over && !widget.paused) {
      // Long frames (backgrounding, debugger) never dump a wave of people.
      final dt = (_now - _last).clamp(0, 100);
      for (final lane in c.rushTick(dt)) {
        if (!c.reducedMotion) motion.arrivals[lane] = _now;
      }
    }
    _last = _now;
    final moving = motion.prune(_now);
    if ((run == null || run.over || widget.paused) && !moving) {
      ticker.stop();
      _base = _now;
    }
    setState(() {});
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  void onLane(int lane) {
    final run = c.rush;
    final scene = _scene;
    if (run == null || run.over || widget.paused || scene == null) return;
    final waitingBefore = run.waiting.toList();
    final serial = run.busesSent;
    final move = c.rushTap(lane);
    if (!move.accepted) return;
    _animate(move, waitingBefore, serial, scene);
    widget.onMove?.call(move);
  }

  /// Animates a booster's effect (rainbow boarding the waiting passengers).
  void boosted(RushMove move, List<BusColor> waitingBefore, int serial) {
    final scene = _scene;
    if (scene != null) _animate(move, waitingBefore, serial, scene);
  }

  void _animate(
    RushMove move,
    List<BusColor> waitingBefore,
    int serial,
    SceneLayout scene,
  ) {
    if (c.reducedMotion) return;
    motion.move(
      scene: scene,
      now: _now,
      lane: move.lane,
      color: move.color ?? BusColor.coral,
      toBus: move.toBus,
      seat: move.seat,
      slot: move.waitingSlot,
      busSerial: serial,
      waitingBefore: waitingBefore,
      fromWaiting: move.fromWaiting,
      departed: move.departed,
    );
    if (!ticker.isActive) {
      _base = _now;
      _last = _now;
      ticker.start();
    }
  }

  ArenaView view(EndlessRun run) => ArenaView(
    lanes: [
      for (final line in run.lanes) [for (final p in line) p.index],
    ],
    waiting: run.waiting,
    slots: run.slots,
    current: run.bus,
    next: run.nextBus,
    boarded: run.boarded,
    capacity: run.config.capacity,
    busSerial: run.busesSent,
    continued: run.extraSlots > 0,
    lockOpen: run.extraSlots == 0 && !run.over,
    playing: !run.over,
    rainbow: run.rainbow,
    skin: c.selectedBus,
    terminal: c.selectedTerminal,
  );

  @override
  Widget build(BuildContext context) {
    final run = c.rush;
    if (!identical(run, _run)) {
      _run = run;
      motion.clear();
    }
    if (run == null) return const SizedBox.shrink();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTicker();
    });
    return LayoutBuilder(
      builder: (context, box) {
        final scene = SceneLayout(
          box.biggest,
          run.lanes.length,
          run.slots,
          top: widget.top,
          capacity: run.config.capacity,
        );
        _scene = scene;
        return ArenaStack(
          scene: scene,
          view: view(run),
          motion: motion,
          now: _now,
          laneLabel: (lane) => run.lanes[lane].isEmpty
              ? 'Empty lane'
              : 'Lane ${lane + 1}: ${colorNames[run.lanes[lane].first.index]} passenger in front, ${run.lanes[lane].length} in line',
          onLane: onLane,
          onLockTap: widget.onLockTap,
        );
      },
    );
  }
}
