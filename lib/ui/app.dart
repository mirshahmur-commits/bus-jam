import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/controller.dart';
import '../game/model.dart';
import 'art.dart';
import 'game_scene.dart';

class BusJamApp extends StatefulWidget {
  const BusJamApp({
    super.key,
    required this.controller,
    this.audioEnabled = true,
  });
  final GameController controller;
  final bool audioEnabled;
  @override
  State<BusJamApp> createState() => _BusJamAppState();
}

class _BusJamAppState extends State<BusJamApp> with WidgetsBindingObserver {
  AudioPlayer? audio;
  int page = 0;
  bool settling = false;
  Timer? settleTimer;
  final messenger = GlobalKey<ScaffoldMessengerState>();
  final navigator = GlobalKey<NavigatorState>();
  GameController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    if (widget.audioEnabled) {
      audio = AudioPlayer();
    }
    WidgetsBinding.instance.addObserver(this);
    c.addListener(changed);
  }

  void changed() {
    if (!mounted) {
      return;
    }
    setState(() {});
    final message = c.takeMessage();
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        messenger.currentState?.showSnackBar(SnackBar(content: Text(message)));
      });
    }
  }

  @override
  void didUpdateWidget(covariant BusJamApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(changed);
      c.addListener(changed);
      settling = false;
      settleTimer?.cancel();
      page = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      c.lifecycle(state.name);
  @override
  void dispose() {
    c.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    audio?.dispose();
    settleTimer?.cancel();
    super.dispose();
  }

  void onMove(MoveResult result) {
    if (c.board.phase(c.level) != GamePhase.playing && !c.reducedMotion) {
      setState(() {
        settling = true;
      });
      settleTimer?.cancel();
      settleTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            settling = false;
          });
        }
      });
    }
    if (c.haptics) {
      unawaited(HapticFeedback.lightImpact());
    }
    if (c.sound && widget.audioEnabled) {
      final sound = c.board.phase(c.level) == GamePhase.won
          ? 'win'
          : c.board.phase(c.level) == GamePhase.failed
          ? 'fail'
          : result.boarding.isNotEmpty
          ? 'board'
          : 'tap';
      unawaited(
        audio!.play(AssetSource('audio/$sound.wav')).catchError((Object e) {}),
      );
    }
  }

  void play() {
    setState(() => page = 1);
    if (!c.onboarded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tutorial());
    }
  }

  void home() {
    if (c.busy) {
      return;
    }
    c.returnToCampaign();
    setState(() => page = 0);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Bus Jam',
    scaffoldMessengerKey: messenger,
    navigatorKey: navigator,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: teal, surface: cream),
      scaffoldBackgroundColor: cream,
      fontFamily: 'Nunito',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, fontSize: 14),
        titleLarge: TextStyle(
          color: ink,
          fontWeight: FontWeight.w900,
          fontSize: 26,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    home: Builder(
      builder: (context) => PopScope(
        canPop: page == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            home();
          }
        },
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE1EBDD),
                  Color(0xFFF5F3E8),
                  Color(0xFFDFEAE3),
                ],
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SafeArea(
                  child: !c.loaded
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                          children: [
                            Positioned.fill(
                              child: page == 0
                                  ? homePage(context)
                                  : page == 1
                                  ? gamePage(context)
                                  : levelsPage(context),
                            ),
                            if (c.busy)
                              Positioned.fill(
                                child: ColoredBox(
                                  color: cream.withValues(alpha: .78),
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('One moment…'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget pill(IconData icon, String text, {Color color = ink}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
  Widget circleButton(
    IconData icon,
    VoidCallback onTap, {
    String? tip,
    Key? key,
  }) => IconButton.filledTonal(
    key: key,
    onPressed: c.busy ? null : onTap,
    tooltip: tip,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .8),
      foregroundColor: ink,
      minimumSize: const Size(46, 46),
    ),
    icon: Icon(icon, size: 21),
  );
  Widget primary(
    String text,
    VoidCallback? onTap, {
    Key? key,
    IconData icon = Icons.arrow_forward_rounded,
  }) => SizedBox(
    width: double.infinity,
    height: 58,
    child: FilledButton(
      key: key,
      onPressed: c.busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(width: 14),
            Icon(icon, size: 23),
          ],
        ),
      ),
    ),
  );
  Widget card(Widget child, {Color color = Colors.white}) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white.withValues(alpha: .8)),
      boxShadow: [
        BoxShadow(
          color: ink.withValues(alpha: .04),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
  Widget homePage(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('home'),
    padding: const EdgeInsets.fromLTRB(25, 20, 25, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'SYSTEMCRAFT\nGAMES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: ink,
                ),
              ),
            ),
            pill(
              Icons.monetization_on_rounded,
              '${c.coins}',
              color: const Color(0xFFAB7A25),
            ),
            const SizedBox(width: 9),
            circleButton(
              Icons.tune_rounded,
              () => settings(context),
              tip: 'Settings',
              key: const ValueKey('settings'),
            ),
          ],
        ),
        const SizedBox(height: 25),
        const Text(
          'Little buses.\nBig brain energy.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: teal,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'BUS JAM',
          style: TextStyle(
            fontSize: 53,
            fontWeight: FontWeight.w900,
            letterSpacing: -3,
            color: ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Find the order. Feel the flow.',
          style: TextStyle(color: Color(0xFF6F8274), fontSize: 15),
        ),
        const SizedBox(height: 23),
        SizedBox(
          height: 245,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: CustomPaint(painter: CityPainter(hero: true)),
          ),
        ),
        const SizedBox(height: 23),
        primary(
          c.board.phase(c.level) == GamePhase.won
              ? 'Route ${c.unlocked} awaits'
              : 'Play route ${c.level.number}',
          () {
            if (c.board.phase(c.level) == GamePhase.won) {
              c.openLevel(c.unlocked);
            }
            play();
          },
          key: const ValueKey('play'),
        ),
        const SizedBox(height: 17),
        card(
          InkWell(
            key: const ValueKey('daily'),
            onTap: () {
              c.openDaily();
              play();
            },
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9E3B6),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.wb_sunny_rounded,
                    color: Color(0xFFBD8732),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily detour',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        c.completedDay ==
                                DateTime.now().toIso8601String().substring(
                                  0,
                                  10,
                                )
                            ? 'Complete · Come back tomorrow'
                            : 'A fresh puzzle. A little ritual.',
                        style: const TextStyle(
                          color: Color(0xFF74847A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: teal),
              ],
            ),
          ),
          color: const Color(0xFFFFFBED),
        ),
        const SizedBox(height: 17),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              key: const ValueKey('routes'),
              onPressed: () => setState(() => page = 2),
              icon: const Icon(Icons.route_rounded),
              label: const Text('Your routes'),
            ),
            pill(
              Icons.local_fire_department_rounded,
              '${c.streak} day streak',
              color: const Color(0xFFA37746),
            ),
          ],
        ),
        if (c.saveFailed)
          const Text(
            'Progress could not be saved. Check available device storage.',
            style: TextStyle(color: Colors.red),
          ),
      ],
    ),
  );
  Widget gamePage(BuildContext context) {
    final phase = c.board.phase(c.level);
    return LayoutBuilder(
      builder: (context, con) {
        final boardHeight = con.maxHeight > 780
            ? minBoardHeight(c, con.maxHeight - 290)
            : minBoardHeight(c, 440);
        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(19, 15, 19, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      circleButton(
                        Icons.arrow_back_rounded,
                        home,
                        tip: 'Home',
                        key: const ValueKey('home-button'),
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          Text(
                            c.dailyMode ? 'DAILY DETOUR' : c.level.district,
                            style: const TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w800,
                              color: teal,
                            ),
                          ),
                          Text(
                            c.dailyMode
                                ? 'Today’s route'
                                : 'Route ${c.level.number}',
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      circleButton(
                        Icons.tune_rounded,
                        () => settings(context),
                        tip: 'Settings',
                        key: const ValueKey('game-settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      Text(
                        '${c.board.cursor} / ${c.level.passengers.length} home',
                        style: const TextStyle(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      pill(
                        Icons.monetization_on_rounded,
                        '${c.coins}',
                        color: const Color(0xFFAB7A25),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: c.board.cursor / c.level.passengers.length,
                      minHeight: 6,
                      color: teal,
                      backgroundColor: const Color(0xFFD8E3D5),
                    ),
                  ),
                  const SizedBox(height: 17),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(27),
                    child: SizedBox(
                      height: boardHeight,
                      child: GameScene(
                        key: ValueKey('scene-${c.level.seed}'),
                        controller: c,
                        onMove: onMove,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    c.hintLane != null
                        ? 'The glowing bus has a winning route.'
                        : c.level.number <= 3
                        ? 'Match the first passenger. Full buses leave automatically.'
                        : 'Keep a parking space open. Think one bus ahead.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6F8274),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      toolButton(
                        context,
                        Assist.undo,
                        Icons.undo_rounded,
                        'Undo',
                      ),
                      const SizedBox(width: 10),
                      toolButton(
                        context,
                        Assist.hint,
                        Icons.lightbulb_outline_rounded,
                        'Hint',
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('restart'),
                          onPressed: c.busy
                              ? null
                              : () => confirmRestart(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 58),
                            side: const BorderSide(color: Color(0xFFCEDBD0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, size: 22),
                              Text(
                                'Restart',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (c.saveFailed)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Save unavailable',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            if (phase != GamePhase.playing && !settling)
              resultOverlay(context, phase),
          ],
        );
      },
    );
  }

  double minBoardHeight(GameController c, double proposed) {
    final depth = c.board.lanes
        .map((l) => l.length.clamp(1, 4))
        .fold(1, (a, b) => a > b ? a : b);
    final needed = 95 + 104 + 85 + (depth - 1) * 34 + 104 + 20;
    return needed.toDouble();
  }

  Widget toolButton(
    BuildContext context,
    Assist action,
    IconData icon,
    String text,
  ) => Expanded(
    child: FilledButton.tonal(
      key: ValueKey(action.name),
      onPressed: c.available(action) ? () => assist(context, action) : null,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        minimumSize: const Size(0, 58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
  Widget resultOverlay(BuildContext context, GamePhase phase) {
    final won = phase == GamePhase.won;
    return Positioned.fill(
      child: Container(
        color: cream.withValues(alpha: .88),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(29),
          child: card(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: won
                        ? const Color(0xFFDDF1D8)
                        : const Color(0xFFFBE0C9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    won ? Icons.celebration_rounded : Icons.traffic_rounded,
                    size: 41,
                    color: won ? teal : const Color(0xFFD38C5B),
                  ),
                ),
                const SizedBox(height: 19),
                Text(
                  won ? 'Smooth operator!' : 'A little traffic…',
                  key: ValueKey(won ? 'win' : 'fail'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  won
                      ? 'Everyone’s on their way.\nYou made that look easy.'
                      : 'Parking is full.\nA different order will clear the jam.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6F8274), height: 1.5),
                ),
                const SizedBox(height: 19),
                if (won)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      pill(
                        Icons.directions_bus_rounded,
                        '${c.board.departed} buses',
                      ),
                      const SizedBox(width: 8),
                      pill(
                        Icons.check_circle_rounded,
                        'All aboard',
                        color: teal,
                      ),
                    ],
                  ),
                const SizedBox(height: 23),
                if (won)
                  primary(c.dailyMode ? 'Back to my routes' : 'Next route', () {
                    if (c.dailyMode) {
                      home();
                    } else {
                      unawaited(c.next());
                    }
                  }, key: const ValueKey('next'))
                else ...[
                  if (!c.board.continued)
                    primary(
                      'One extra space',
                      () => assist(context, Assist.extraSlot),
                      key: const ValueKey('continue'),
                      icon: Icons.add_rounded,
                    ),
                  const SizedBox(height: 10),
                  if (c.history.isNotEmpty)
                    TextButton(
                      key: const ValueKey('fail-undo'),
                      onPressed: () => assist(context, Assist.undo),
                      child: const Text('Undo the last bus'),
                    ),
                  TextButton(
                    key: const ValueKey('fail-restart'),
                    onPressed: c.restart,
                    child: const Text('Start this route again'),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(onPressed: home, child: const Text('Home')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget levelsPage(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Row(
          children: [
            circleButton(Icons.arrow_back_rounded, home, tip: 'Home'),
            const SizedBox(width: 15),
            const Expanded(
              child: Text(
                'Your routes',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
            ),
            pill(Icons.check_rounded, '${c.unlocked - 1}'),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 18),
        child: Text(
          'One satisfying little journey at a time.',
          style: TextStyle(color: teal),
        ),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 13,
            mainAxisSpacing: 13,
          ),
          itemCount: ((c.unlocked + 19) ~/ 20) * 20,
          itemBuilder: (context, i) {
            final n = i + 1, open = n <= c.unlocked, complete = n < c.unlocked;
            return FilledButton(
              key: ValueKey('level-$n'),
              onPressed: open
                  ? () {
                      c.openLevel(n);
                      play();
                    }
                  : null,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: n == c.unlocked ? teal : Colors.white,
                foregroundColor: n == c.unlocked ? Colors.white : ink,
                disabledBackgroundColor: Colors.white.withValues(alpha: .35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  open
                      ? Text(
                          '$n',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : const Icon(Icons.lock_outline_rounded, size: 20),
                  if (complete)
                    const Icon(Icons.check_rounded, size: 15, color: teal),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
  Future<void> sheet(BuildContext context, Widget child) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: cream,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              25,
              4,
              25,
              25 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: child,
          ),
        ),
      );
  Future<void> tutorial() => sheet(
    navigator.currentState!.overlay!.context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Let’s get everyone home.',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        const SizedBox(height: 20),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.touch_app_rounded, color: teal),
          title: Text('Tap a front bus'),
          subtitle: Text('Send it into an open parking space.'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.people_alt_rounded, color: teal),
          title: Text('Match the first passenger'),
          subtitle: Text('Same color and symbol. They board in order.'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.directions_bus_rounded, color: teal),
          title: Text('Full buses roll out'),
          subtitle: Text('Keep a space free to avoid a traffic jam.'),
        ),
        const SizedBox(height: 20),
        primary('Got it. Let’s go!', () {
          c.finishOnboarding();
          navigator.currentState!.pop();
        }, key: const ValueKey('tutorial-done')),
      ],
    ),
  );
  Future<void> assist(BuildContext context, Assist action) async {
    if (!c.available(action)) {
      return;
    }
    final title = switch (action) {
      Assist.hint => 'A nudge in the right direction',
      Assist.undo => 'Let’s back that bus up',
      Assist.extraSlot => 'Make a little room',
    };
    await sheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(switch (action) {
            Assist.hint => 'Highlight a bus that leads to a solution.',
            Assist.undo => 'Return to the state before your last move.',
            Assist.extraSlot => 'Add one parking space for this attempt.',
          }),
          const SizedBox(height: 24),
          primary(
            'Use ${c.cost(action)} coins',
            c.coins >= c.cost(action)
                ? () {
                    Navigator.pop(context);
                    c.spend(action);
                  }
                : null,
            key: const ValueKey('use-coins'),
            icon: Icons.monetization_on_rounded,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('watch-ad'),
              onPressed: () {
                Navigator.pop(context);
                unawaited(c.watch(action));
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Watch a video · free'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Only a completed rewarded video grants the assist.',
            style: TextStyle(fontSize: 11, color: Color(0xFF74847A)),
          ),
        ],
      ),
    );
  }

  Future<void> confirmRestart(BuildContext context) => sheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Try a fresh start?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'This route stays the same. Your coins and completed routes stay with you.',
        ),
        const SizedBox(height: 24),
        primary(
          'Restart route',
          () {
            Navigator.pop(context);
            c.restart();
          },
          key: const ValueKey('confirm-restart'),
          icon: Icons.refresh_rounded,
        ),
      ],
    ),
  );
  Future<void> settings(BuildContext context) async {
    final price = c.purchases.price();
    if (!context.mounted) {
      return;
    }
    await sheet(
      context,
      StatefulBuilder(
        builder: (ctx, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your kind of calm.',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              key: const ValueKey('sound-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Sound'),
              secondary: const Icon(Icons.volume_up_rounded, color: teal),
              value: c.sound,
              onChanged: (v) {
                c.settings(sound: v);
                update(() {});
              },
            ),
            SwitchListTile(
              key: const ValueKey('haptics-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Haptics'),
              secondary: const Icon(Icons.vibration_rounded, color: teal),
              value: c.haptics,
              onChanged: (v) {
                c.settings(haptics: v);
                update(() {});
              },
            ),
            SwitchListTile(
              key: const ValueKey('motion-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduce motion'),
              secondary: const Icon(
                Icons.accessibility_new_rounded,
                color: teal,
              ),
              value: c.reducedMotion,
              onChanged: (v) {
                c.settings(reducedMotion: v);
                update(() {});
              },
            ),
            const Divider(height: 28),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block_rounded, color: teal),
              title: Text(
                c.removeAds ? 'Automatic ads removed' : 'Remove automatic ads',
              ),
              subtitle: FutureBuilder<String?>(
                future: price,
                builder: (context, snapshot) => Text(
                  c.removeAds
                      ? 'Rewarded videos remain optional'
                      : snapshot.connectionState == ConnectionState.waiting
                      ? 'Checking store price…'
                      : (snapshot.data ??
                            'Store price is currently unavailable'),
                ),
              ),
              trailing: c.removeAds
                  ? const Icon(Icons.check_circle_rounded, color: teal)
                  : const Icon(Icons.chevron_right_rounded),
              onTap: c.removeAds
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      unawaited(c.buyRemoveAds());
                    },
            ),
            TextButton(
              key: const ValueKey('restore-purchases'),
              onPressed: () {
                Navigator.pop(ctx);
                unawaited(c.restorePurchases());
              },
              child: const Text('Restore purchases'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                unawaited(c.ads.privacyOptions());
              },
              child: const Text('Advertising privacy choices'),
            ),
            TextButton(
              key: const ValueKey('privacy'),
              onPressed: () => sheet(
                ctx,
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Game progress and settings are stored on this device. The game works offline.\n\nWhen advertising is configured, Google Mobile Ads may process device and advertising information according to your consent choices. Automatic ads are removed by the Remove Ads purchase; rewarded videos are optional.\n\nPurchases are handled by Apple. No payment details are stored by this game.\n\nYou can reset advertising consent in Advertising privacy choices. Deleting the app removes its local data.',
                      style: TextStyle(height: 1.6),
                    ),
                  ],
                ),
              ),
              child: const Text('Privacy information'),
            ),
            const SizedBox(height: 14),
            const Text(
              'BUS JAM  /  1.0.0\nMade for a little everyday joy.',
              style: TextStyle(
                color: Color(0xFF8E9B8E),
                fontSize: 11,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
