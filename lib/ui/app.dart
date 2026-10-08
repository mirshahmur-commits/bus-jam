import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/controller.dart';
import '../game/model.dart';
import '../game/progression.dart';
import 'art.dart';
import 'depot_preview.dart';
import 'game_scene.dart';
import 'urban_assets.dart';

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
      settleTimer = Timer(const Duration(milliseconds: 460), () {
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
          bottomNavigationBar: page == 1 ? null : NavigationBar(
            selectedIndex: page == 0 ? 0 : page - 1,
            onDestinationSelected: (index) {
              if (!c.busy) setState(() => page = index == 0 ? 0 : index + 1);
            },
            backgroundColor: cream,
            height: 68,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Depot'),
              NavigationDestination(icon: Icon(Icons.route_rounded), label: 'Map'),
              NavigationDestination(icon: Icon(Icons.directions_bus_rounded), label: 'Garage'),
              NavigationDestination(icon: Icon(Icons.emoji_events_rounded), label: 'Records'),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE4E8ED),
                  Color(0xFFF2F1ED),
                  Color(0xFFDCE2E8),
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
                                  : page == 2
                                  ? levelsPage(context)
                                  : page == 3
                                  ? garagePage(context)
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('BUS SURGE', key: ValueKey('wordmark'), style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.6)))),
        pill(Icons.monetization_on_rounded, '${c.coins}', color: const Color(0xFFAB7A25)),
        const SizedBox(width: 5),
        circleButton(Icons.tune_rounded, () => settings(context), tip: 'Settings', key: const ValueKey('settings')),
      ]),
      const SizedBox(height: 20),
      Row(children: [Expanded(child: Text(c.rank, style: const TextStyle(color: teal, fontWeight: FontWeight.w800))), Text('${c.totalStars} ★', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFAE7D28)))]),
      const SizedBox(height: 7),
      const Text('Your next\nperfect dispatch.', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, height: 1.08, letterSpacing: -.8)),
      const SizedBox(height: 16),
      primary('Continue · Route ${c.board.phase(c.level) == GamePhase.won ? c.unlocked : c.level.number}', () {
        if (c.dailyMode) c.returnToCampaign();
        if (c.board.phase(c.level) == GamePhase.won) c.openLevel(c.unlocked);
        play();
      }, key: const ValueKey('play'), icon: Icons.play_arrow_rounded),
      const SizedBox(height: 15),
      SizedBox(height: 150, width: double.infinity, child: DepotPreview(skin: c.selectedBus, terminal: c.selectedTerminal)),
      const SizedBox(height: 14),
      card(InkWell(key: const ValueKey('garage-goal'), onTap: () => setState(() => page = 3), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.auto_awesome_rounded, color: teal, size: 20), const SizedBox(width: 8), Expanded(child: Text(c.ownedCosmetics.length == cosmetics.length ? 'Your collection is complete' : 'Next: ${c.nextCollectible.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), const Icon(Icons.chevron_right_rounded, color: teal)]),
        const SizedBox(height: 7),
        Text(c.ownedCosmetics.length == cosmetics.length ? 'Pick a favourite in your garage.' : c.coins >= c.nextCollectible.price ? 'Ready to unlock in your garage.' : '${c.nextCollectible.price - c.coins} more coins to make it yours.', style: const TextStyle(color: Color(0xFF687789), fontSize: 12)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: c.ownedCosmetics.length == cosmetics.length ? 1 : (c.coins / c.nextCollectible.price).clamp(0.0, 1.0), color: teal, backgroundColor: const Color(0xFFDDE8E7), minHeight: 5)),
      ]))),
      const SizedBox(height: 14),
      card(InkWell(key: const ValueKey('daily'), onTap: () { c.openDaily(); play(); }, child: Row(children: [
        const Icon(Icons.wb_sunny_rounded, color: Color(0xFFBA852E), size: 28), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Daily dispatch', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), Text(c.dailyRecord == null ? 'One shared puzzle · 75 coins' : 'Best ${c.dailyRecord!.score} · ${c.streak} day streak', style: const TextStyle(color: Color(0xFF687789), fontSize: 12))])),
        const Icon(Icons.chevron_right_rounded, color: teal),
      ])), color: const Color(0xFFFFF8E8)),
      const SizedBox(height: 7),
      TextButton.icon(key: const ValueKey('routes'), onPressed: () => setState(() => page = 2), icon: const Icon(Icons.route_rounded), label: Text('${c.unlocked - 1} routes cleared · Explore the map')),
      if (c.saveFailed) const Text('Progress could not be saved. Check available device storage.', style: TextStyle(color: Colors.red)),
    ]),
  );

  Widget gamePage(BuildContext context) {
    final phase = c.board.phase(c.level);
    return LayoutBuilder(builder: (context, constraints) => Stack(children: [
      SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 20), child: Column(children: [
        Row(children: [
          circleButton(Icons.arrow_back_rounded, home, tip: 'Home', key: const ValueKey('home-button')),
          Expanded(child: Column(children: [
            Text(c.dailyMode ? 'DAILY DISPATCH' : c.level.hard ? 'CHALLENGE ROUTE' : c.level.district, style: const TextStyle(fontSize: 9, letterSpacing: 1.3, color: teal, fontWeight: FontWeight.w900)),
            Text(c.dailyMode ? 'Today’s route' : 'Route ${c.level.number}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          ])),
          circleButton(Icons.tune_rounded, () => settings(context), tip: 'Settings', key: const ValueKey('game-settings')),
        ]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: Text('${c.board.cursor} / ${c.level.passengers.length} delivered', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))), pill(Icons.monetization_on_rounded, '${c.coins}', color: const Color(0xFFAB7A25))]),
        const SizedBox(height: 7),
        ClipRRect(borderRadius: BorderRadius.circular(7), child: LinearProgressIndicator(value: c.board.cursor / c.level.passengers.length, minHeight: 5, color: teal, backgroundColor: const Color(0xFFD9E3E5))),
        Row(children: [Expanded(child: Text(c.level.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))), TextButton.icon(key: const ValueKey('queue-preview'), onPressed: () => previewQueue(context), icon: const Icon(Icons.visibility_outlined, size: 17), label: const Text('Plan', style: TextStyle(fontSize: 12)))]),
        ClipRRect(borderRadius: BorderRadius.circular(22), child: SizedBox(height: SceneLayout.heightFor(constraints.maxWidth - 36, c.level), child: GameScene(key: ValueKey('scene-${c.level.generatorVersion}-${c.level.number}-${c.level.seed}'), controller: c, onMove: onMove))),
        const SizedBox(height: 10),
        Row(children: [const Icon(Icons.star_rounded, color: Color(0xFFB9852E), size: 18), const SizedBox(width: 5), Expanded(child: Text('Perfect route: parking cost ≤ ${c.level.parkingTarget}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))), Text('${c.parkingCost}', key: const ValueKey('parking-cost'), style: TextStyle(fontWeight: FontWeight.w900, color: c.parkingCost > c.level.parkingTarget ? const Color(0xFFB77A36) : teal)), IconButton(onPressed: () => scoreHelp(context), icon: const Icon(Icons.info_outline_rounded, size: 18), visualDensity: VisualDensity.compact)]),
        Text(c.hintLane == null ? c.level.lesson : 'The glowing bus leads to a winning route.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF687789))),
        const SizedBox(height: 13),
        Row(children: [toolButton(context, Assist.undo, Icons.undo_rounded, 'Undo'), const SizedBox(width: 9), toolButton(context, Assist.hint, Icons.lightbulb_outline_rounded, 'Hint'), const SizedBox(width: 9), Expanded(child: OutlinedButton(key: const ValueKey('restart'), onPressed: c.busy ? null : () => confirmRestart(context), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 58), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.refresh_rounded, size: 22), Text('Restart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))])))]),
        if (c.saveFailed) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Save unavailable', style: TextStyle(color: Colors.red))),
      ])),
      if (phase != GamePhase.playing && !settling) resultOverlay(context, phase),
    ]));
  }

  Future<void> previewQueue(BuildContext context) => sheet(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Plan your dispatch', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    const Text('Passengers board in this order. Looking ahead is always free.'),
    const SizedBox(height: 16),
    Wrap(spacing: 5, runSpacing: 5, children: [for (int i = c.board.cursor; i < c.level.passengers.length; i++) Chip(label: Text('${i - c.board.cursor + 1}', style: const TextStyle(fontWeight: FontWeight.w900)), avatar: Icon(Icons.person_rounded, color: ink, size: 18), backgroundColor: busColors[c.level.passengers[i].index], side: BorderSide.none, padding: EdgeInsets.zero)]),
    const SizedBox(height: 16),
    for (int lane = 0; lane < c.board.lanes.length; lane++) ...[
      Text('Exit ${lane + 1} · front bus first', style: const TextStyle(fontWeight: FontWeight.w900)),
      Wrap(spacing: 5, children: [for (final bus in c.board.lanes[lane]) Chip(label: Text('${colorNames[bus.color.index]} · ${bus.capacity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), backgroundColor: busColors[bus.color.index].withValues(alpha: .55), side: BorderSide.none)]),
    ],
  ]));

  Future<void> scoreHelp(BuildContext context) => sheet(context, const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('A perfect dispatch', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
    SizedBox(height: 16),
    Text('★ Finish the route.\n★★ Finish with the original parking spaces.\n★★★ Match the route’s parking target without a hint.\n\nParking cost adds the number of waiting buses after each move. A lower total means a cleaner route. One free undo lets you learn; it does not remove a star.\n\nScore: 1,000 for completion, up to 600 for parking efficiency, 250 for original spaces and 150 without hints. Daily ranking accepts runs without hints, undos or extra spaces.', style: TextStyle(height: 1.6)),
  ]));

  Widget toolButton(BuildContext context, Assist action, IconData icon, String text) => Expanded(child: FilledButton.tonal(
    key: ValueKey(action.name),
    onPressed: c.available(action) ? () { if (c.cost(action) == 0) { c.spend(action); } else { assist(context, action); } } : null,
    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ink, minimumSize: const Size(0, 58), padding: const EdgeInsets.symmetric(horizontal: 5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 21), Text('$text · ${c.cost(action) == 0 ? 'FREE' : c.cost(action)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))]),
  ));

  Widget resultOverlay(BuildContext context, GamePhase phase) {
    final won = phase == GamePhase.won;
    final result = c.lastResult;
    return Positioned.fill(child: ColoredBox(color: cream.withValues(alpha: .96), child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(25), child: card(Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(height: won ? 90 : 100, width: double.infinity, child: UrbanArtwork(won ? 'win' : 'fail')),
      const SizedBox(height: 12),
      Text(won ? result?.stars == 3 ? 'Perfect dispatch!' : 'Route complete!' : 'Terminal full', key: ValueKey(won ? 'win' : 'fail'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
      if (won) ...[
        const SizedBox(height: 10),
        Row(key: const ValueKey('result-stars'), mainAxisAlignment: MainAxisAlignment.center, children: [for (int i = 0; i < 3; i++) Icon(i < (result?.stars ?? 1) ? Icons.star_rounded : Icons.star_outline_rounded, size: 43, color: const Color(0xFFE2AD3C))]),
        const SizedBox(height: 7),
        Text('${result?.score ?? 1000}', key: const ValueKey('score'), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: teal)),
        Text(result?.personalBest == true ? 'NEW PERSONAL BEST' : 'DISPATCH SCORE', key: const ValueKey('personal-best'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 7, children: [pill(Icons.monetization_on_rounded, '+${result?.reward ?? 0}', color: const Color(0xFFAB7A25)), pill(Icons.local_parking_rounded, '${result?.parkingCost ?? c.parkingCost} / ${c.level.parkingTarget}')]),
        const SizedBox(height: 12),
        Text(c.dailyMode ? result?.ranked == true ? 'Clean run · ready for daily ranking.' : 'Practice result · assists used.' : '${10 - ((c.unlocked - 1) % 10)} routes to the next district.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF687789))),
        const SizedBox(height: 19),
        primary(c.dailyMode ? 'Back to my routes' : 'Next route', () { if (c.dailyMode) { home(); } else { unawaited(c.next()); } }, key: const ValueKey('next')),
        if (c.dailyMode && c.leaderboards.enabled) TextButton.icon(key: const ValueKey('daily-ranking'), onPressed: () => unawaited(c.showDailyRanking()), icon: const Icon(Icons.leaderboard_rounded), label: const Text('Daily leaderboard')),
        TextButton(key: const ValueKey('replay'), onPressed: c.restart, child: const Text('Replay for a better result')),
        TextButton(key: const ValueKey('win-garage'), onPressed: () { c.returnToCampaign(); setState(() => page = 3); }, child: const Text('Visit my garage')),
      ] else ...[
        const SizedBox(height: 10),
        Text('${c.board.slots} spaces are occupied. ${colorNames[c.level.passengers[c.board.cursor].index]} passengers need their bus.\nTry a different release order.', textAlign: TextAlign.center, style: const TextStyle(height: 1.5, color: Color(0xFF687789))),
        const SizedBox(height: 20),
        if (c.history.isNotEmpty) primary(c.cost(Assist.undo) == 0 ? 'Undo · FREE' : 'Undo the last bus', () { if (c.cost(Assist.undo) == 0) { c.spend(Assist.undo); } else { assist(context, Assist.undo); } }, key: const ValueKey('fail-undo'), icon: Icons.undo_rounded),
        if (!c.board.continued) TextButton(key: const ValueKey('continue'), onPressed: () => assist(context, Assist.extraSlot), child: Text('Extra space · ${c.cost(Assist.extraSlot)} coins')),
        TextButton(key: const ValueKey('fail-restart'), onPressed: c.restart, child: const Text('Restart this route')),
      ],
      TextButton(onPressed: home, child: const Text('Home')),
    ]))))));
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
                  if (complete) Text(c.routeRecord(n) == null ? '✓' : List.filled(c.routeRecord(n)!.stars, '★').join(), style: const TextStyle(fontSize: 11, color: teal, fontWeight: FontWeight.w900)),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
  Widget garagePage(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('garage'), padding: const EdgeInsets.all(22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [circleButton(Icons.arrow_back_rounded, home, tip: 'Home', key: const ValueKey('garage-back')), const SizedBox(width: 10), const Expanded(child: Text('Your garage', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900))), pill(Icons.monetization_on_rounded, '${c.coins}', color: const Color(0xFFAB7A25))]),
      const SizedBox(height: 10),
      const Text('Earn coins on routes. Make your fleet your own.', style: TextStyle(color: Color(0xFF687789))),
      const SizedBox(height: 17),
      for (final kind in CosmeticKind.values) ...[
        Text(kind == CosmeticKind.bus ? 'THE FLEET' : 'YOUR TERMINAL', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5, color: teal)),
        const SizedBox(height: 12),
        for (final item in cosmetics.where((item) => item.kind == kind)) ...[
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: 108, width: double.infinity, child: DepotPreview(skin: kind == CosmeticKind.bus ? item.id : c.selectedBus, terminal: kind == CosmeticKind.terminal ? item.id : c.selectedTerminal, busOnly: kind == CosmeticKind.bus)),
            const SizedBox(height: 12),
            Text(item.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(item.description, style: const TextStyle(fontSize: 12, color: Color(0xFF687789))),
            const SizedBox(height: 12),
            primary((kind == CosmeticKind.bus ? c.selectedBus : c.selectedTerminal) == item.id ? 'Equipped' : c.ownedCosmetics.contains(item.id) ? 'Equip' : 'Unlock · ${item.price} coins', (kind == CosmeticKind.bus ? c.selectedBus : c.selectedTerminal) == item.id ? null : c.ownedCosmetics.contains(item.id) ? () => c.equipCosmetic(item.id) : c.coins >= item.price ? () => c.buyCosmetic(item.id) : null, key: ValueKey('cosmetic-${item.id}'), icon: c.ownedCosmetics.contains(item.id) ? Icons.check_rounded : Icons.monetization_on_rounded),
            if (!c.ownedCosmetics.contains(item.id) && c.coins < item.price) Padding(padding: const EdgeInsets.only(top: 7), child: Text('${item.price - c.coins} more coins needed', style: const TextStyle(fontSize: 11, color: Color(0xFF687789)))),
          ])),
          const SizedBox(height: 14),
        ],
      ],
    ]),
  );

  Widget recordsPage(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('records'), padding: const EdgeInsets.all(22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [circleButton(Icons.arrow_back_rounded, home, tip: 'Home', key: const ValueKey('records-back')), const SizedBox(width: 12), const Expanded(child: Text('Your records', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)))]),
      const SizedBox(height: 18),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.rank, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: teal)), const SizedBox(height: 10), Text('${c.totalStars} stars · ${c.perfectRoutes} perfect routes', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('15 stars: City Dispatcher\n45 stars: Route Expert\n90 stars: Depot Master', style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF687789)))])),
      const SizedBox(height: 16),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Daily dispatch', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(c.dailyRecord == null ? 'Today’s puzzle is waiting.' : 'Today’s personal best: ${c.dailyRecord!.score}'), const SizedBox(height: 10), primary('Play today’s route', () { c.openDaily(); play(); }, key: const ValueKey('records-daily'), icon: Icons.wb_sunny_rounded)])),
      if (c.leaderboards.enabled) TextButton.icon(key: const ValueKey('game-center'), onPressed: () => unawaited(c.showDailyRanking()), icon: const Icon(Icons.leaderboard_rounded), label: const Text('Daily leaderboard')),
      const SizedBox(height: 19),
      const Text('PERSONAL BESTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: teal)),
      const SizedBox(height: 9),
      if (c.totalStars == 0) const Text('Finish your first route to set a record.'),
      for (final entry in c.records.entries.where((e) => e.key.startsWith('2:')).toList()..sort((a, b) => int.parse(a.key.split(':').last).compareTo(int.parse(b.key.split(':').last))))
        ListTile(contentPadding: EdgeInsets.zero, title: Text('Route ${entry.key.split(':').last}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(List.filled(entry.value.stars, '★').join()), trailing: Text('${entry.value.score}', style: const TextStyle(fontWeight: FontWeight.w900, color: teal)), onTap: () { c.openLevel(int.parse(entry.key.split(':').last)); play(); }),
    ]),
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(alignment: Alignment.centerRight, child: IconButton(key: const ValueKey('sheet-close'), onPressed: () => Navigator.pop(ctx), tooltip: 'Close', icon: const Icon(Icons.close_rounded))),
              child,
            ]),
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
              'BUS SURGE  /  1.1.0\nYour city. Your next move.',
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
