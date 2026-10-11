import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/controller.dart';
import '../game/endless.dart';
import '../game/model.dart';
import '../game/progression.dart';
import 'art.dart';
import 'depot_preview.dart';
import 'game_scene.dart';
import 'rush_scene.dart';

const boosterNames = {
  Booster.rainbow: 'Rainbow',
  Booster.slow: 'Slow-mo',
  Booster.taxi: 'Taxi',
};
const boosterDescriptions = {
  Booster.rainbow: 'For 30 seconds anyone boards any bus.',
  Booster.slow: 'For 20 seconds the crowd arrives at half speed.',
  Booster.taxi: 'A taxi takes everyone in the waiting slots.',
};
const boosterBlocked = {
  Booster.rainbow: 'Rainbow is already running.',
  Booster.slow: 'Slow-mo is already running.',
  Booster.taxi: 'Nobody is waiting for a taxi.',
};
const boosterIcons = {
  Booster.rainbow: Icons.auto_awesome_rounded,
  Booster.slow: Icons.hourglass_bottom_rounded,
  Booster.taxi: Icons.local_taxi_rounded,
};
const boosterColors = {
  Booster.rainbow: [Color(0xFFFF8FD8), Color(0xFF9B4DE8)],
  Booster.slow: [Color(0xFF7FD3FF), Color(0xFF2E7BE6)],
  Booster.taxi: [Color(0xFFFFD45C), Color(0xFFF59E0B)],
};
const upgradeNames = {
  Upgrade.bigBus: 'Bigger buses',
  Upgrade.wideStop: 'Wider stop',
  Upgrade.calmCrowd: 'Calm crowd',
};
const upgradeDescriptions = {
  Upgrade.bigBus: 'One more seat on every rush bus.',
  Upgrade.wideStop: 'One more waiting slot in every rush.',
  Upgrade.calmCrowd: 'The crowd starts a little slower.',
};
const upgradeIcons = {
  Upgrade.bigBus: Icons.airport_shuttle_rounded,
  Upgrade.wideStop: Icons.chair_rounded,
  Upgrade.calmCrowd: Icons.self_improvement_rounded,
};

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    c.lifecycle(state.name);
    // Leaving the app pauses a live rush; it resumes from the pause menu.
    final run = c.rush;
    if (state != AppLifecycleState.resumed &&
        page == 5 &&
        run != null &&
        !run.over &&
        !rushPaused) {
      final context = navigator.currentContext;
      if (context != null) unawaited(pauseRush(() => rushMenu(context)));
    }
  }

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
      settleTimer = Timer(const Duration(milliseconds: 2500), () {
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
          : result.toBus || result.fromWaiting.isNotEmpty
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
    if (page == 5) c.settleRush();
    c.returnToCampaign();
    setState(() => page = 0);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Bus Surge',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          bottomNavigationBar: page == 1 || page == 5
              ? null
              : NavigationBar(
                  selectedIndex: page == 0 ? 0 : page - 1,
                  onDestinationSelected: (index) {
                    if (!c.busy) {
                      setState(() => page = index == 0 ? 0 : index + 1);
                    }
                  },
                  backgroundColor: cream,
                  height: 68,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_rounded),
                      label: 'Depot',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.route_rounded),
                      label: 'Map',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.directions_bus_rounded),
                      label: 'Garage',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.emoji_events_rounded),
                      label: 'Records',
                    ),
                  ],
                ),
          body: Container(
            decoration: BoxDecoration(
              color: page == 1 || page == 5
                  ? ArenaPalette.forId(c.selectedTerminal).sky
                  : null,
              gradient: page == 1 || page == 5
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFDCDAFA), Color(0xFFF1F0FF)],
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
                                  : page == 2
                                  ? levelsPage(context)
                                  : page == 3
                                  ? garagePage(context)
                                  : page == 5
                                  ? rushPage(context)
                                  : recordsPage(context),
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
  }) => Container(
    width: double.infinity,
    height: 62,
    padding: const EdgeInsets.only(bottom: 5),
    decoration: BoxDecoration(
      // A darker base under the button gives it a chunky, pressable edge.
      color: const Color(0xFF1C8A4A),
      borderRadius: BorderRadius.circular(18),
    ),
    child: FilledButton(
      key: key,
      onPressed: c.busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF34C46F),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF9FD8B5),
        elevation: 0,
        minimumSize: const Size.fromHeight(57),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
      borderRadius: BorderRadius.circular(16),
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
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'BUS SURGE',
                  key: ValueKey('wordmark'),
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.6,
                  ),
                ),
              ),
            ),
            pill(
              Icons.monetization_on_rounded,
              '${c.coins}',
              color: const Color(0xFFAB7A25),
            ),
            const SizedBox(width: 5),
            circleButton(
              Icons.tune_rounded,
              () => settings(context),
              tip: 'Settings',
              key: const ValueKey('settings'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                c.rank,
                style: const TextStyle(
                  color: teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${c.totalStars}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFFAE7D28),
              ),
            ),
            const Icon(Icons.star_rounded, size: 18, color: Color(0xFFE2AD3C)),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8E8AD6), Color(0xFF5B4FD6)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ENDLESS RUSH',
                style: TextStyle(
                  color: Color(0xFFFFE07A),
                  fontSize: 13,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'The crowd never stops.\nHow long can you last?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                c.bestScore > 0
                    ? 'Your record: ${c.bestScore}'
                    : 'Set your first record',
                key: const ValueKey('best-score'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              primary(
                'Rush',
                startRush,
                key: const ValueKey('rush'),
                icon: Icons.bolt_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        primary(
          'Puzzle · Level ${c.board.phase(c.level) == GamePhase.won ? c.unlocked : c.level.number}',
          () {
            if (c.dailyMode) c.returnToCampaign();
            if (c.board.phase(c.level) == GamePhase.won) {
              c.openLevel(c.unlocked);
            }
            play();
          },
          key: const ValueKey('play'),
          icon: Icons.play_arrow_rounded,
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 150,
          width: double.infinity,
          child: DepotPreview(
            skin: c.selectedBus,
            terminal: c.selectedTerminal,
          ),
        ),
        const SizedBox(height: 14),
        card(
          InkWell(
            key: const ValueKey('garage-goal'),
            onTap: () => setState(() => page = 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: teal,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.ownedCosmetics.length == cosmetics.length
                            ? 'Your collection is complete'
                            : 'Next: ${c.nextCollectible.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: teal),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  c.ownedCosmetics.length == cosmetics.length
                      ? 'Pick a favourite in your garage.'
                      : c.coins >= c.nextCollectible.price
                      ? 'Ready to unlock in your garage.'
                      : '${c.nextCollectible.price - c.coins} more coins to make it yours.',
                  style: const TextStyle(
                    color: Color(0xFF687789),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: c.ownedCosmetics.length == cosmetics.length
                        ? 1
                        : (c.coins / c.nextCollectible.price).clamp(0.0, 1.0),
                    color: teal,
                    backgroundColor: const Color(0xFFDDE8E7),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        card(
          InkWell(
            key: const ValueKey('daily'),
            onTap: () {
              c.openDaily();
              play();
            },
            child: Row(
              children: [
                const Icon(
                  Icons.wb_sunny_rounded,
                  color: Color(0xFFBA852E),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily dispatch',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        c.dailyRecord == null
                            ? 'One shared puzzle · 75 coins'
                            : 'Best ${c.dailyRecord!.score} · ${c.streak} day streak',
                        style: const TextStyle(
                          color: Color(0xFF687789),
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
          color: const Color(0xFFFFF8E8),
        ),
        const SizedBox(height: 7),
        TextButton.icon(
          key: const ValueKey('routes'),
          onPressed: () => setState(() => page = 2),
          icon: const Icon(Icons.route_rounded),
          label: Text('${c.unlocked - 1} routes cleared · Explore the map'),
        ),
        if (c.saveFailed)
          const Text(
            'Progress could not be saved. Check available device storage.',
            style: TextStyle(color: Colors.red),
          ),
      ],
    ),
  );

  Widget hudButton(
    IconData icon,
    VoidCallback? onTap, {
    required String tip,
    Key? key,
    List<Color> colors = const [Color(0xFF5AB8FF), Color(0xFF2E7BE6)],
    String? badge,
    double size = 50,
  }) => Tooltip(
    message: tip,
    child: GestureDetector(
      key: key,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .55 : 1,
        child: SizedBox(
          width: size + 8,
          height: size + 6,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x553B3680), offset: Offset(0, 3)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: size * .52),
              ),
              if (badge != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B3680),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget hudPill(
    Widget leading,
    String text, {
    Key? key,
    VoidCallback? onTap,
  }) => GestureDetector(
    key: key,
    onTap: onTap,
    child: Container(
      height: 34,
      padding: const EdgeInsets.only(left: 2, right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B3680).withValues(alpha: .72),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );

  Widget gamePage(BuildContext context) {
    final phase = c.board.phase(c.level);
    const top = 58.0;
    return Stack(
      children: [
        Positioned.fill(
          child: GameScene(
            key: ValueKey(
              'scene-${c.level.generatorVersion}-${c.level.number}-${c.level.seed}',
            ),
            controller: c,
            onMove: onMove,
            top: top,
            onLockTap: () {
              if (c.available(Assist.extraSlot)) {
                assist(context, Assist.extraSlot);
              }
            },
            onIdle: () {
              settleTimer?.cancel();
              if (settling && mounted) setState(() => settling = false);
            },
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          top: 8,
          child: Row(
            children: [
              hudButton(
                Icons.arrow_back_rounded,
                home,
                tip: 'Home',
                key: const ValueKey('home-button'),
                size: 40,
                colors: const [Color(0xFF7C76E0), Color(0xFF524BC0)],
              ),
              hudPill(
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFFFFC93C),
                  size: 30,
                ),
                '${c.coins}',
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B3680).withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Text(
                        c.dailyMode ? 'DAILY' : 'LEVEL ${c.level.number}',
                        key: const ValueKey('level-title'),
                        style: TextStyle(
                          color: c.level.hard
                              ? const Color(0xFFFFD45C)
                              : Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              hudPill(
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    color: Color(0xFFFFC93C),
                    size: 20,
                  ),
                ),
                '${c.level.buses.length - c.board.busIndex}',
                key: const ValueKey('queue-preview'),
                onTap: () => previewQueue(context),
              ),
            ],
          ),
        ),
        Positioned(
          left: 8,
          top: top + 8,
          child: Column(
            children: [
              hudButton(
                Icons.settings_rounded,
                () => settings(context),
                tip: 'Settings',
                key: const ValueKey('game-settings'),
              ),
              const SizedBox(height: 6),
              hudButton(
                Icons.refresh_rounded,
                c.busy ? null : () => confirmRestart(context),
                tip: 'Restart',
                key: const ValueKey('restart'),
                colors: const [Color(0xFFD38BFF), Color(0xFF9B4DE8)],
              ),
            ],
          ),
        ),
        Positioned(
          right: 8,
          top: top + 8,
          child: Column(
            children: [
              toolButton(context, Assist.hint, Icons.lightbulb_rounded, 'Hint'),
              const SizedBox(height: 6),
              toolButton(context, Assist.undo, Icons.undo_rounded, 'Undo'),
            ],
          ),
        ),
        if (c.hintLane != null || c.level.number <= 8 && c.board.moves < 4)
          Positioned(
            left: 24,
            right: 24,
            bottom: 14,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B3680).withValues(alpha: .85),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    c.hintLane == null
                        ? c.level.lesson
                        : 'Tap the glowing lane.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (c.saveFailed)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: Text(
              'Save unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
        if (phase != GamePhase.playing && !settling)
          resultOverlay(context, phase),
      ],
    );
  }

  final rushKey = GlobalKey<RushSceneState>();
  bool rushPaused = false;

  void startRush() {
    c.startRush();
    setState(() {
      rushPaused = false;
      page = 5;
    });
  }

  void onRushMove(RushMove move) {
    if (c.haptics) {
      unawaited(HapticFeedback.lightImpact());
    }
    final run = c.rush!;
    if (run.over && run.end == RushEnd.overflow) c.settleRush();
    if (c.sound && widget.audioEnabled) {
      final sound = run.over
          ? 'fail'
          : move.toBus || move.fromWaiting.isNotEmpty
          ? 'board'
          : 'tap';
      unawaited(
        audio!.play(AssetSource('audio/$sound.wav')).catchError((Object e) {}),
      );
    }
  }

  Future<void> pauseRush(Future<void> Function() action) async {
    setState(() => rushPaused = true);
    await action();
    if (mounted) setState(() => rushPaused = false);
  }

  void useBooster(Booster b) {
    final run = c.rush;
    if (run == null) return;
    if ((c.boosters[b] ?? 0) < 1) {
      if (!c.buyBooster(b)) {
        messenger.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              'Not enough coins. ${boosterNames[b]} costs ${boosterPrices[b]}.',
            ),
          ),
        );
        return;
      }
    }
    final waitingBefore = run.waiting.toList();
    final serial = run.busesSent;
    final move = c.useBooster(b);
    if (move == null) {
      messenger.currentState?.showSnackBar(
        SnackBar(content: Text(boosterBlocked[b]!)),
      );
      return;
    }
    rushKey.currentState?.boosted(move, waitingBefore, serial);
  }

  Widget boosterButton(Booster b, EndlessRun run) {
    final active = switch (b) {
      Booster.rainbow => run.rainbow,
      Booster.slow => run.slow,
      Booster.taxi => false,
    };
    final left = switch (b) {
      Booster.rainbow => (run.rainbowUntil - run.clock) ~/ 1000 + 1,
      Booster.slow => (run.slowUntil - run.clock) ~/ 1000 + 1,
      Booster.taxi => 0,
    };
    final owned = c.boosters[b] ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        hudButton(
          boosterIcons[b]!,
          run.over && b != Booster.taxi || active ? null : () => useBooster(b),
          tip: boosterNames[b]!,
          key: ValueKey('booster-${b.name}'),
          size: 54,
          colors: boosterColors[b]!,
          badge: active
              ? '${left}s'
              : owned > 0
              ? '×$owned'
              : '${boosterPrices[b]}',
        ),
        Text(
          boosterNames[b]!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget rushPage(BuildContext context) {
    final run = c.rush;
    if (run == null) return const SizedBox.shrink();
    const top = 58.0;
    return Stack(
      children: [
        Positioned.fill(
          child: RushScene(
            key: rushKey,
            controller: c,
            top: top,
            paused: rushPaused || page != 5,
            onMove: onRushMove,
            onLockTap: () {
              if (!c.rushContinue()) {
                messenger.currentState?.showSnackBar(
                  const SnackBar(
                    content: Text('An extra slot costs 50 coins.'),
                  ),
                );
              }
            },
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          top: 8,
          child: Row(
            children: [
              hudButton(
                Icons.pause_rounded,
                () => pauseRush(() => rushMenu(context)),
                tip: 'Pause',
                key: const ValueKey('rush-pause'),
                size: 40,
                colors: const [Color(0xFF7C76E0), Color(0xFF524BC0)],
              ),
              hudPill(
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFFFFC93C),
                  size: 30,
                ),
                '${c.coins}',
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${run.score}',
                          key: const ValueKey('rush-score'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Color(0xFF3B3680),
                                offset: Offset(0, 2.5),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          run.score > c.bestScore && c.bestScore > 0
                              ? 'NEW BEST!'
                              : 'BEST ${c.bestScore}',
                          style: const TextStyle(
                            color: Color(0xFFFFE07A),
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              hudPill(
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    color: Color(0xFFFFC93C),
                    size: 20,
                  ),
                ),
                '${run.busesSent}',
              ),
            ],
          ),
        ),
        if (run.streak >= 3)
          Positioned(
            right: 12,
            top: top + 10,
            child: IgnorePointer(
              child: Text(
                'COMBO ×${run.streak}',
                style: const TextStyle(
                  color: Color(0xFFFFE07A),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Color(0xFF3B3680), offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF3B3680).withValues(alpha: 0),
                  const Color(0xFF3B3680).withValues(alpha: .8),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 22, 0, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final b in Booster.values) boosterButton(b, run),
                ],
              ),
            ),
          ),
        ),
        if (run.over) rushOverlay(context, run),
      ],
    );
  }

  Future<void> rushMenu(BuildContext context) => sheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paused',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text('Score ${c.rush?.score ?? 0} · Best ${c.bestScore}'),
        const SizedBox(height: 18),
        primary('Resume', () {
          navigator.currentState!.pop();
        }, key: const ValueKey('rush-resume')),
        TextButton(
          key: const ValueKey('rush-quit'),
          onPressed: () {
            navigator.currentState!.pop();
            c.settleRush();
            setState(() => page = 0);
          },
          child: const Text('End run and go home'),
        ),
        TextButton(
          onPressed: () {
            navigator.currentState!.pop();
            settings(context);
          },
          child: const Text('Settings'),
        ),
      ],
    ),
  );

  Widget rushOverlay(BuildContext context, EndlessRun run) {
    final canContinue =
        !c.rushSettled && run.end == RushEnd.slotsFull && run.extraSlots == 0;
    final canTaxi =
        !c.rushSettled &&
        run.end == RushEnd.slotsFull &&
        (c.boosters[Booster.taxi] ?? 0) > 0;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xFF2A2660).withValues(alpha: .55),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: card(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: CustomPaint(painter: ResultArtPainter(false)),
                  ),
                  Text(
                    run.end == RushEnd.overflow
                        ? 'Crowd overflow!'
                        : 'Stop jammed!',
                    key: const ValueKey('rush-over'),
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${run.score}',
                    key: const ValueKey('rush-final'),
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: teal,
                    ),
                  ),
                  Text(
                    c.rushSettled
                        ? c.rushNewBest
                              ? 'NEW PERSONAL BEST!'
                              : 'BEST ${c.bestScore}'
                        : run.score > c.bestScore
                        ? 'NEW BEST — KEEP GOING?'
                        : 'BEST ${c.bestScore}',
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      pill(Icons.people_alt_rounded, '${run.delivered}'),
                      pill(Icons.directions_bus_rounded, '${run.busesSent}'),
                      pill(
                        Icons.monetization_on_rounded,
                        '+${c.rushSettled ? c.rushReward : run.coins}',
                        color: const Color(0xFFAB7A25),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (canTaxi)
                    TextButton.icon(
                      key: const ValueKey('rush-taxi'),
                      onPressed: () => useBooster(Booster.taxi),
                      icon: const Icon(Icons.local_taxi_rounded),
                      label: Text(
                        'Call a taxi for the waiting · ×${c.boosters[Booster.taxi]}',
                      ),
                    ),
                  if (canContinue)
                    TextButton.icon(
                      key: const ValueKey('rush-continue'),
                      onPressed: c.coins >= 50 ? c.rushContinue : null,
                      icon: const Icon(Icons.add_box_rounded),
                      label: const Text('Extra slot and continue · 50 coins'),
                    ),
                  primary(
                    'Play again',
                    () {
                      c.settleRush();
                      startRush();
                    },
                    key: const ValueKey('rush-again'),
                    icon: Icons.replay_rounded,
                  ),
                  TextButton(
                    key: const ValueKey('rush-shop'),
                    onPressed: () {
                      c.settleRush();
                      setState(() => page = 3);
                    },
                    child: const Text('Upgrades and boosters'),
                  ),
                  TextButton(
                    key: const ValueKey('rush-home'),
                    onPressed: () {
                      c.settleRush();
                      setState(() => page = 0);
                    },
                    child: const Text('Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> previewQueue(BuildContext context) => sheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bus line-up',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Buses arrive in this order. Each one seats three passengers.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (int i = c.board.busIndex; i < c.level.buses.length; i++)
              Chip(
                avatar: const Icon(Icons.directions_bus_rounded, size: 18),
                label: Text(
                  i == c.board.busIndex
                      ? '${colorNames[c.level.buses[i].index]} · ${c.board.boarded}/3'
                      : colorNames[c.level.buses[i].index],
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                backgroundColor: busColors[c.level.buses[i].index],
                side: BorderSide.none,
              ),
          ],
        ),
      ],
    ),
  );

  Future<void> scoreHelp(BuildContext context) => sheet(
    context,
    const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Three-star rush',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 16),
        Text(
          '★ Board everyone.\n★★ Finish without the extra slot.\n★★★ Keep the waiting score at or under the target without a hint.\n\nThe waiting score adds up how many passengers stand in the slots after each tap. Send people straight to their bus to keep it low. One free undo lets you learn; it does not remove a star.\n\nScore: 1,000 for completion, up to 600 for a low waiting score, 250 without the extra slot and 150 without hints. Daily ranking accepts runs without hints, undos or extra slots.',
          style: TextStyle(height: 1.6),
        ),
      ],
    ),
  );

  Widget toolButton(
    BuildContext context,
    Assist action,
    IconData icon,
    String text,
  ) => hudButton(
    icon,
    c.available(action)
        ? () {
            if (c.cost(action) == 0) {
              c.spend(action);
            } else {
              assist(context, action);
            }
          }
        : null,
    tip: text,
    key: ValueKey(action.name),
    badge: c.cost(action) == 0 ? 'FREE' : '${c.cost(action)}',
    colors: action == Assist.hint
        ? const [Color(0xFFFFD45C), Color(0xFFF59E0B)]
        : const [Color(0xFF6EE7A8), Color(0xFF22B573)],
  );

  Widget resultOverlay(BuildContext context, GamePhase phase) {
    final won = phase == GamePhase.won;
    final result = c.lastResult;
    return Positioned.fill(
      child: ColoredBox(
        color: cream.withValues(alpha: .96),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: card(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: won ? 90 : 100,
                    width: double.infinity,
                    child: CustomPaint(painter: ResultArtPainter(won)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    won
                        ? result?.stars == 3
                              ? 'Perfect!'
                              : 'Level complete!'
                        : 'Slots full!',
                    key: ValueKey(won ? 'win' : 'fail'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (won) ...[
                    const SizedBox(height: 10),
                    Row(
                      key: const ValueKey('result-stars'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < 3; i++)
                          Icon(
                            i < (result?.stars ?? 1)
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 43,
                            color: const Color(0xFFE2AD3C),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${result?.score ?? 1000}',
                      key: const ValueKey('score'),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: teal,
                      ),
                    ),
                    Text(
                      result?.personalBest == true
                          ? 'NEW PERSONAL BEST'
                          : 'DISPATCH SCORE',
                      key: const ValueKey('personal-best'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 7,
                      children: [
                        pill(
                          Icons.monetization_on_rounded,
                          '+${result?.reward ?? 0}',
                          color: const Color(0xFFAB7A25),
                        ),
                        pill(
                          Icons.chair_rounded,
                          '${result?.parkingCost ?? c.parkingCost} / ${c.level.parkingTarget}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      c.dailyMode
                          ? result?.ranked == true
                                ? 'Clean run · ready for daily ranking.'
                                : 'Practice result · assists used.'
                          : '${10 - ((c.unlocked - 1) % 10)} routes to the next district.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF687789),
                      ),
                    ),
                    const SizedBox(height: 19),
                    primary(
                      c.dailyMode ? 'Back to my routes' : 'Next level',
                      () {
                        if (c.dailyMode) {
                          home();
                        } else {
                          unawaited(c.next());
                        }
                      },
                      key: const ValueKey('next'),
                    ),
                    if (c.dailyMode && c.leaderboards.enabled)
                      TextButton.icon(
                        key: const ValueKey('daily-ranking'),
                        onPressed: () => unawaited(c.showDailyRanking()),
                        icon: const Icon(Icons.leaderboard_rounded),
                        label: const Text('Daily leaderboard'),
                      ),
                    TextButton(
                      key: const ValueKey('replay'),
                      onPressed: c.restart,
                      child: const Text('Replay for a better result'),
                    ),
                    TextButton(
                      key: const ValueKey('win-garage'),
                      onPressed: () {
                        c.returnToCampaign();
                        setState(() => page = 3);
                      },
                      child: const Text('Visit my garage'),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Text(
                      'All ${c.board.slots} waiting slots are full.\nThe ${colorNames[c.board.currentBus(c.level)!.index]} bus is still waiting for its passengers.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        height: 1.5,
                        color: Color(0xFF687789),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (c.history.isNotEmpty)
                      primary(
                        c.cost(Assist.undo) == 0
                            ? 'Undo · FREE'
                            : 'Undo the last tap',
                        () {
                          if (c.cost(Assist.undo) == 0) {
                            c.spend(Assist.undo);
                          } else {
                            assist(context, Assist.undo);
                          }
                        },
                        key: const ValueKey('fail-undo'),
                        icon: Icons.undo_rounded,
                      ),
                    if (!c.board.continued)
                      TextButton(
                        key: const ValueKey('continue'),
                        onPressed: () => assist(context, Assist.extraSlot),
                        child: Text(
                          'Extra slot · ${c.cost(Assist.extraSlot)} coins',
                        ),
                      ),
                    TextButton(
                      key: const ValueKey('fail-restart'),
                      onPressed: c.restart,
                      child: const Text('Restart this route'),
                    ),
                  ],
                  TextButton(onPressed: home, child: const Text('Home')),
                ],
              ),
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
            pill(Icons.star_rounded, '${c.totalStars}'),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 18),
        child: Text(
          'Collect stars. Open the next district.',
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
                  borderRadius: BorderRadius.circular(12),
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
                    Text(
                      c.routeRecord(n) == null
                          ? '✓'
                          : List.filled(c.routeRecord(n)!.stars, '★').join(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: teal,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
  Widget shopHeading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 12,
        letterSpacing: 1.5,
        color: teal,
      ),
    ),
  );

  Widget shopRow({
    required IconData icon,
    required List<Color> colors,
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback? onTap,
    required Key key,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: card(
      Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: colors),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF687789),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: key,
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF34C46F),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              action,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    ),
  );

  Widget upgradeCard(Upgrade u) {
    final level = c.upgrades[u] ?? 0;
    final price = upgradePrice(u, level);
    return shopRow(
      icon: upgradeIcons[u]!,
      colors: const [Color(0xFF6EE7A8), Color(0xFF22B573)],
      title: '${upgradeNames[u]} · $level/${upgradeMax(u)}',
      subtitle: upgradeDescriptions[u]!,
      action: price == null ? 'MAX' : '$price',
      onTap: price == null || c.coins < price ? null : () => c.buyUpgrade(u),
      key: ValueKey('upgrade-${u.name}'),
    );
  }

  Widget boosterCard(Booster b) => shopRow(
    icon: boosterIcons[b]!,
    colors: boosterColors[b]!,
    title: '${boosterNames[b]} · ×${c.boosters[b] ?? 0}',
    subtitle: boosterDescriptions[b]!,
    action: '${boosterPrices[b]}',
    onTap: c.coins < boosterPrices[b]! ? null : () => c.buyBooster(b),
    key: ValueKey('buy-${b.name}'),
  );

  Widget garagePage(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('garage'),
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            circleButton(
              Icons.arrow_back_rounded,
              home,
              tip: 'Home',
              key: const ValueKey('garage-back'),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Your garage',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
              ),
            ),
            pill(
              Icons.monetization_on_rounded,
              '${c.coins}',
              color: const Color(0xFFAB7A25),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Earn coins in rushes and puzzles. Spend them here.',
          style: TextStyle(color: Color(0xFF687789)),
        ),
        const SizedBox(height: 17),
        shopHeading('RUSH UPGRADES'),
        for (final u in Upgrade.values) upgradeCard(u),
        const SizedBox(height: 10),
        shopHeading('BOOSTERS'),
        for (final b in Booster.values) boosterCard(b),
        const SizedBox(height: 10),
        for (final kind in CosmeticKind.values) ...[
          Text(
            kind == CosmeticKind.bus ? 'THE FLEET' : 'YOUR TERMINAL',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.5,
              color: teal,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in cosmetics.where((item) => item.kind == kind)) ...[
            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 108,
                    width: double.infinity,
                    child: DepotPreview(
                      skin: kind == CosmeticKind.bus ? item.id : c.selectedBus,
                      terminal: kind == CosmeticKind.terminal
                          ? item.id
                          : c.selectedTerminal,
                      busOnly: kind == CosmeticKind.bus,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF687789),
                    ),
                  ),
                  const SizedBox(height: 12),
                  primary(
                    (kind == CosmeticKind.bus
                                ? c.selectedBus
                                : c.selectedTerminal) ==
                            item.id
                        ? 'Equipped'
                        : c.ownedCosmetics.contains(item.id)
                        ? 'Equip'
                        : 'Unlock · ${item.price} coins',
                    (kind == CosmeticKind.bus
                                ? c.selectedBus
                                : c.selectedTerminal) ==
                            item.id
                        ? null
                        : c.ownedCosmetics.contains(item.id)
                        ? () => c.equipCosmetic(item.id)
                        : c.coins >= item.price
                        ? () => c.buyCosmetic(item.id)
                        : null,
                    key: ValueKey('cosmetic-${item.id}'),
                    icon: c.ownedCosmetics.contains(item.id)
                        ? Icons.check_rounded
                        : Icons.monetization_on_rounded,
                  ),
                  if (!c.ownedCosmetics.contains(item.id) &&
                      c.coins < item.price)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        '${item.price - c.coins} more coins needed',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF687789),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ],
    ),
  );

  Widget recordsPage(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('records'),
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            circleButton(
              Icons.arrow_back_rounded,
              home,
              tip: 'Home',
              key: const ValueKey('records-back'),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Your records',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.rank,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: teal,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${c.totalStars} stars · ${c.perfectRoutes} perfect routes',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '15 stars: City Dispatcher\n45 stars: Route Expert\n90 stars: Depot Master',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF687789),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily dispatch',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                c.dailyRecord == null
                    ? 'Today’s puzzle is waiting.'
                    : 'Today’s personal best: ${c.dailyRecord!.score}',
              ),
              const SizedBox(height: 10),
              primary(
                'Play today’s route',
                () {
                  c.openDaily();
                  play();
                },
                key: const ValueKey('records-daily'),
                icon: Icons.wb_sunny_rounded,
              ),
            ],
          ),
        ),
        if (c.leaderboards.enabled)
          TextButton.icon(
            key: const ValueKey('game-center'),
            onPressed: () => unawaited(c.showDailyRanking()),
            icon: const Icon(Icons.leaderboard_rounded),
            label: const Text('Daily leaderboard'),
          ),
        const SizedBox(height: 19),
        const Text(
          'PERSONAL BESTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: teal,
          ),
        ),
        const SizedBox(height: 9),
        if (c.totalStars == 0)
          const Text('Finish your first route to set a record.'),
        for (final entry
            in c.records.entries.where((e) => e.key.startsWith('2:')).toList()
              ..sort(
                (a, b) => int.parse(
                  a.key.split(':').last,
                ).compareTo(int.parse(b.key.split(':').last)),
              ))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Route ${entry.key.split(':').last}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(List.filled(entry.value.stars, '★').join()),
            trailing: Text(
              '${entry.value.score}',
              style: const TextStyle(fontWeight: FontWeight.w900, color: teal),
            ),
            onTap: () {
              c.openLevel(int.parse(entry.key.split(':').last));
              play();
            },
          ),
      ],
    ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const ValueKey('sheet-close'),
                    onPressed: () => Navigator.pop(ctx),
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                child,
              ],
            ),
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
          title: Text('Tap a passenger with a clear path'),
          subtitle: Text('Blocked passengers wait until the way opens.'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.people_alt_rounded, color: teal),
          title: Text('Match the bus colour'),
          subtitle: Text('Others wait in the slots and board later.'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.directions_bus_rounded, color: teal),
          title: Text('Full buses roll out'),
          subtitle: Text('Fill all five slots and the stop jams.'),
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
            Assist.extraSlot => 'Add one waiting slot for this attempt.',
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
                  borderRadius: BorderRadius.circular(12),
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
              'BUS SURGE  /  2.1.0\nYour city. Your next move.',
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
