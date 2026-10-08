import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../platform/analytics.dart';
import '../platform/leaderboards.dart';
import '../platform/monetization.dart';
import '../platform/progress_store.dart';
import 'engine.dart';
import 'generator.dart';
import 'model.dart';
import 'progression.dart';

enum Assist { hint, undo, extraSlot }

class GameController extends ChangeNotifier {
  GameController({
    required this.store,
    AnalyticsPort? analytics,
    AdsPort? ads,
    PurchasesPort? purchases,
    LeaderboardsPort? leaderboards,
    DateTime Function()? clock,
  }) : analytics = analytics ?? LocalAnalytics(),
       ads = ads ?? OfflineAds(),
       purchases = purchases ?? OfflinePurchases(),
       leaderboards = leaderboards ?? const OfflineLeaderboards(),
       clock = clock ?? DateTime.now {
    level = generator.generate(1);
    board = Board.initial(level);
  }
  final ProgressStore store;
  final AnalyticsPort analytics;
  final AdsPort ads;
  final PurchasesPort purchases;
  final LeaderboardsPort leaderboards;
  final DateTime Function() clock;
  final generator = LevelGenerator();
  late Level level;
  late Board board;
  List<Board> history = [];
  int unlocked = 1, coins = 150, totalWins = 0, streak = 0, attempts = 1;
  bool loaded = false,
      busy = false,
      sound = true,
      haptics = true,
      reducedMotion = false,
      removeAds = false,
      dailyMode = false,
      onboarded = false;
  bool saveFailed = false;
  String? completedDay, message;
  int? hintLane;
  DateTime? lastAd;
  AdPolicy adPolicy = const AdPolicy();
  MoveResult? lastMove;
  RouteResult? lastResult;
  final records = <String, RouteRecord>{};
  final rankedDailyScores = <String, int>{};
  final ownedCosmetics = <String>{'classic', 'terminal-classic'};
  String selectedBus = 'classic', selectedTerminal = 'terminal-classic';
  bool usedHint = false, freeUndoUsed = false;
  int undosUsed = 0;
  int get parkingCost =>
      history.fold(0, (sum, b) => sum + b.parked.length) + board.parked.length;
  String get recordKey => dailyMode
      ? 'daily:${level.seed}'
      : '${level.generatorVersion}:${level.number}';
  RouteRecord? routeRecord(int number) => records['2:$number'];
  RouteRecord? get dailyRecord =>
      records['daily:${int.parse(_day(clock().toUtc()).replaceAll('-', ''))}'];
  int get totalStars => records.entries
      .where((e) => e.key.startsWith('2:'))
      .fold(0, (sum, e) => sum + e.value.stars);
  int get perfectRoutes => records.entries
      .where((e) => e.key.startsWith('2:') && e.value.stars == 3)
      .length;
  String get rank => totalStars >= 90
      ? 'Depot Master'
      : totalStars >= 45
      ? 'Route Expert'
      : totalStars >= 15
      ? 'City Dispatcher'
      : 'Rookie Dispatcher';
  Cosmetic get nextCollectible => cosmetics.firstWhere(
    (item) => !ownedCosmetics.contains(item.id),
    orElse: () => cosmetics.last,
  );
  Map<String, dynamic>? _campaign;
  int _epoch = 0;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  Future<void> load() async {
    try {
      final raw = await store.read();
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        if (j['schema'] != 1 && j['schema'] != 2) {
          throw const FormatException('Unknown save schema');
        }
        final nextUnlocked = j['unlocked'] as int;
        final nextCoins = j['coins'] as int;
        if (nextUnlocked < 1 || nextCoins < 0 || nextCoins > 1000000) {
          throw const FormatException('Invalid progress');
        }
        final saved = _parseSession(j['session'] as Map<String, dynamic>);
        unlocked = nextUnlocked;
        coins = nextCoins;
        level = saved.$1;
        board = saved.$2;
        history = saved.$3;
        _restoreRun(j['session'] as Map<String, dynamic>);
        dailyMode = j['daily'] as bool;
        if (!dailyMode && level.number > unlocked) {
          throw const FormatException('Locked saved level');
        }
        _campaign = j['campaign'] == null
            ? null
            : Map<String, dynamic>.from(j['campaign'] as Map);
        if (_campaign != null) {
          _parseSession(_campaign!);
        }
        completedDay = j['completedDay'] as String?;
        streak = (j['streak'] as int).clamp(0, 100000);
        totalWins = (j['wins'] as int).clamp(0, 1000000);
        attempts = (j['attempts'] as int).clamp(1, 100000);
        sound = j['sound'] as bool;
        haptics = j['haptics'] as bool;
        reducedMotion = j['reducedMotion'] as bool;
        removeAds = j['removeAds'] as bool;
        onboarded = j['onboarded'] as bool;
        lastAd = j['lastAd'] == null
            ? null
            : DateTime.parse(j['lastAd'] as String);
        if (j['schema'] == 2) {
          final savedRecords = j['records'] as Map<String, dynamic>? ?? {};
          if (savedRecords.length > 10000) {
            throw const FormatException('Too many records');
          }
          for (final entry in savedRecords.entries) {
            if (!RegExp(r'^(1|2|daily):[0-9]+$').hasMatch(entry.key)) {
              throw const FormatException('Invalid record key');
            }
            records[entry.key] = RouteRecord.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
          }
          for (final entry
              in (j['rankedDailyScores'] as Map<String, dynamic>? ?? {})
                  .entries) {
            final value = entry.value as int;
            if (!RegExp(r'^[0-9]{8}$').hasMatch(entry.key) ||
                value < 0 ||
                value > 2000) {
              throw const FormatException('Invalid ranked score');
            }
            rankedDailyScores[entry.key] = value;
          }
          for (final id in (j['ownedCosmetics'] as List? ?? const [])) {
            if (id is String && cosmeticById(id) != null) {
              ownedCosmetics.add(id);
            }
          }
          final bus = j['selectedBus'] as String? ?? 'classic';
          final terminal =
              j['selectedTerminal'] as String? ?? 'terminal-classic';
          if (ownedCosmetics.contains(bus) &&
              cosmeticById(bus)?.kind == CosmeticKind.bus) {
            selectedBus = bus;
          }
          if (ownedCosmetics.contains(terminal) &&
              cosmeticById(terminal)?.kind == CosmeticKind.terminal) {
            selectedTerminal = terminal;
          }
        }
      }
    } catch (_) {
      level = generator.generate(1);
      board = Board.initial(level);
      history = [];
      unlocked = 1;
      coins = 150;
      dailyMode = false;
      _campaign = null;
      records.clear();
      rankedDailyScores.clear();
      ownedCosmetics
        ..clear()
        ..addAll(['classic', 'terminal-classic']);
      selectedBus = 'classic';
      selectedTerminal = 'terminal-classic';
      _resetRun();
      message = 'Your save could not be read. A fresh route is ready.';
      analytics.track('save_recovered', {});
    }
    loaded = true;
    analytics.track('session_start', {'level': level.number});
    _track('level_start');
    notifyListeners();
  }

  (Level, Board, List<Board>) _parseSession(Map<String, dynamic> j) {
    final l = Level.fromJson(Map<String, dynamic>.from(j['level'] as Map));
    final b = Board.fromJson(Map<String, dynamic>.from(j['board'] as Map), l);
    final h = (j['history'] as List)
        .map((v) => Board.fromJson(Map<String, dynamic>.from(v as Map), l))
        .toList();
    if (h.length > 60) {
      throw const FormatException('Invalid undo history');
    }
    return (l, b, h);
  }

  Map<String, dynamic> _session() => {
    'level': level.toJson(),
    'board': board.toJson(),
    'history': history.map((b) => b.toJson()).toList(),
    'run': {
      'usedHint': usedHint,
      'freeUndoUsed': freeUndoUsed,
      'undosUsed': undosUsed,
      'attempts': attempts,
      'result': lastResult?.toJson(),
    },
  };
  void _resetRun() {
    usedHint = false;
    freeUndoUsed = false;
    undosUsed = 0;
    lastResult = null;
  }

  void _restoreRun(Map<String, dynamic> session) {
    _resetRun();
    final run = session['run'] as Map<String, dynamic>?;
    if (run == null) return;
    usedHint = run['usedHint'] as bool;
    freeUndoUsed = run['freeUndoUsed'] as bool;
    undosUsed = run['undosUsed'] as int;
    attempts = run['attempts'] as int;
    if (undosUsed < 0 || undosUsed > 10000 || attempts < 1) {
      throw const FormatException('Invalid run');
    }
    lastResult = run['result'] == null
        ? null
        : RouteResult.fromJson(Map<String, dynamic>.from(run['result'] as Map));
  }

  String snapshot() => jsonEncode({
    'schema': 2,
    'unlocked': unlocked,
    'coins': coins,
    'session': _session(),
    'campaign': _campaign,
    'daily': dailyMode,
    'completedDay': completedDay,
    'streak': streak,
    'wins': totalWins,
    'attempts': attempts,
    'sound': sound,
    'haptics': haptics,
    'reducedMotion': reducedMotion,
    'removeAds': removeAds,
    'onboarded': onboarded,
    'lastAd': lastAd?.toIso8601String(),
    'records': records.map((key, value) => MapEntry(key, value.toJson())),
    'rankedDailyScores': rankedDailyScores,
    'ownedCosmetics': ownedCosmetics.toList()..sort(),
    'selectedBus': selectedBus,
    'selectedTerminal': selectedTerminal,
  });
  Future<void> save() {
    final value = snapshot();
    _writes = _writes
        .then((_) => store.write(value))
        .then((_) {
          saveFailed = false;
        })
        .catchError((Object e) {
          saveFailed = true;
          analytics.track('save_error', {});
          if (!_disposed) {
            notifyListeners();
          }
        });
    return _writes;
  }

  void _track(String event, [Map<String, Object> extra = const {}]) =>
      analytics.track(event, {
        'level': level.number,
        'seed': level.seed,
        'daily': dailyMode,
        'attempt': attempts,
        ...extra,
      });
  void _changed() {
    unawaited(save());
    if (!_disposed) {
      notifyListeners();
    }
  }

  MoveResult release(int lane, {int? expectedBusId}) {
    if (busy ||
        (expectedBusId != null &&
            (lane < 0 ||
                lane >= board.lanes.length ||
                board.lanes[lane].isEmpty ||
                board.lanes[lane].first.id != expectedBusId))) {
      return MoveResult(board);
    }
    final result = GameEngine.release(level, board, lane);
    if (!result.accepted) {
      return result;
    }
    history.add(board);
    if (history.length > 60) {
      history.removeAt(0);
    }
    board = result.board;
    lastMove = result;
    hintLane = null;
    _epoch++;
    _track('bus_release', {'lane': lane, 'boarded': result.boarding.length});
    if (board.phase(level) == GamePhase.won) {
      var reward = 0;
      if (dailyMode) {
        final day = _day(clock().toUtc());
        if (completedDay != day &&
            level.seed == int.parse(day.replaceAll('-', ''))) {
          streak =
              completedDay ==
                  _day(clock().toUtc().subtract(const Duration(days: 1)))
              ? streak + 1
              : 1;
          completedDay = day;
          reward = 75;
        }
      } else if (level.number == unlocked) {
        unlocked++;
        reward = 25;
      }
      coins += reward;
      final evaluated = evaluateRoute(
        level,
        board,
        parkingCost: parkingCost,
        usedHint: usedHint,
      );
      final previous = records[recordKey];
      final improved =
          previous == null ||
          evaluated.score > previous.score ||
          evaluated.stars > previous.stars;
      if (improved) {
        records[recordKey] = RouteRecord(
          score: previous == null
              ? evaluated.score
              : (evaluated.score > previous.score
                    ? evaluated.score
                    : previous.score),
          stars: previous == null
              ? evaluated.stars
              : (evaluated.stars > previous.stars
                    ? evaluated.stars
                    : previous.stars),
          parkingCost: previous == null
              ? parkingCost
              : (parkingCost < previous.parkingCost
                    ? parkingCost
                    : previous.parkingCost),
        );
      }
      lastResult = RouteResult(
        score: evaluated.score,
        stars: evaluated.stars,
        parkingCost: parkingCost,
        target: level.parkingTarget,
        reward: reward,
        personalBest: improved,
        ranked:
            level.generatorVersion == LevelGenerator.version &&
            !usedHint &&
            undosUsed == 0 &&
            !board.continued,
      );
      if (dailyMode &&
          lastResult!.ranked &&
          level.seed == int.parse(_day(clock().toUtc()).replaceAll('-', ''))) {
        final key = '${level.seed}';
        if (evaluated.score > (rankedDailyScores[key] ?? 0)) {
          rankedDailyScores[key] = evaluated.score;
        }
        unawaited(
          leaderboards
              .submit(DailyScore(level.seed, rankedDailyScores[key]!))
              .catchError((Object _) => false),
        );
      }
      totalWins++;
      _track('level_win', {
        'moves': board.moves,
        'reward': reward,
        'score': evaluated.score,
        'stars': evaluated.stars,
        'parkingCost': parkingCost,
      });
    } else if (board.phase(level) == GamePhase.failed) {
      _track('level_fail', {'moves': board.moves});
    }
    _changed();
    return result;
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  void restart() {
    if (busy) {
      return;
    }
    _epoch++;
    attempts++;
    board = Board.initial(level);
    history = [];
    hintLane = null;
    lastMove = null;
    _resetRun();
    _track('restart');
    _track('level_start');
    _changed();
  }

  void openLevel(int number) {
    if (busy || number < 1 || number > unlocked) {
      return;
    }
    _epoch++;
    dailyMode = false;
    _campaign = null;
    level = generator.generate(number);
    board = Board.initial(level);
    history = [];
    attempts = 1;
    hintLane = null;
    lastMove = null;
    _resetRun();
    _track('level_start');
    _changed();
  }

  Future<void> next() async {
    if (busy || board.phase(level) != GamePhase.won || dailyMode) {
      return;
    }
    if (adPolicy.allows(
      level: level.number,
      wins: totalWins,
      removed: removeAds,
      now: clock(),
      lastAd: lastAd,
    )) {
      busy = true;
      notifyListeners();
      var shown = false;
      try {
        shown = await ads.interstitial();
      } catch (_) {
        _track('ad_no_reward', {'outcome': 'error'});
      }
      if (_disposed) {
        return;
      }
      if (shown) {
        lastAd = clock();
        _track('ad_impression', {'format': 'interstitial'});
      }
      busy = false;
    }
    openLevel(level.number + 1);
  }

  void openDaily() {
    if (busy) {
      return;
    }
    if (!dailyMode) {
      _campaign = _session();
    }
    _epoch++;
    dailyMode = true;
    level = generator.daily(clock());
    board = Board.initial(level);
    history = [];
    attempts = 1;
    hintLane = null;
    lastMove = null;
    _resetRun();
    _track('level_start');
    _changed();
  }

  void returnToCampaign() {
    if (busy || !dailyMode) {
      return;
    }
    final saved = _campaign;
    _epoch++;
    dailyMode = false;
    _campaign = null;
    if (saved != null) {
      final parsed = _parseSession(saved);
      level = parsed.$1;
      board = parsed.$2;
      history = parsed.$3;
      _restoreRun(saved);
    } else {
      level = generator.generate(unlocked);
      board = Board.initial(level);
      history = [];
      _resetRun();
    }
    hintLane = null;
    lastMove = null;
    _changed();
  }

  int cost(Assist action) => switch (action) {
    Assist.hint => 25,
    Assist.undo => freeUndoUsed ? 20 : 0,
    Assist.extraSlot => 50,
  };
  bool available(Assist action) =>
      !busy &&
      switch (action) {
        Assist.hint => board.phase(level) == GamePhase.playing,
        Assist.undo =>
          history.isNotEmpty && board.phase(level) != GamePhase.won,
        Assist.extraSlot =>
          board.phase(level) == GamePhase.failed && !board.continued,
      };
  bool _assist(Assist action, {required bool paid}) {
    if (!available(action) || (paid && coins < cost(action))) {
      return false;
    }
    final price = cost(action);
    if (action == Assist.hint) {
      final route = GameEngine.solve(level, board);
      if (route == null || route.isEmpty) {
        message = 'This route is blocked. Undo a move or restart.';
        notifyListeners();
        return false;
      }
      hintLane = route.first;
      usedHint = true;
    } else if (action == Assist.undo) {
      final continued = board.continued;
      final previous = history.removeLast();
      board = continued
          ? Board(
              lanes: previous.lanes,
              parked: previous.parked,
              cursor: previous.cursor,
              departed: previous.departed,
              moves: previous.moves,
              slots: level.slots + 1,
              continued: true,
            )
          : previous;
      hintLane = null;
      lastMove = null;
      freeUndoUsed = true;
      undosUsed++;
    } else {
      board = GameEngine.continueWithSlot(level, board);
    }
    if (paid) {
      coins -= price;
    }
    _epoch++;
    _track(action.name, {
      'source': paid ? (price == 0 ? 'free' : 'coins') : 'rewarded',
    });
    _changed();
    return true;
  }

  bool spend(Assist action) => _assist(action, paid: true);
  bool buyCosmetic(String id) {
    final item = cosmeticById(id);
    if (busy ||
        item == null ||
        ownedCosmetics.contains(id) ||
        coins < item.price) {
      return false;
    }
    coins -= item.price;
    ownedCosmetics.add(id);
    if (item.kind == CosmeticKind.bus) {
      selectedBus = id;
    } else {
      selectedTerminal = id;
    }
    _track('collection_buy', {'item': id, 'cost': item.price});
    _changed();
    return true;
  }

  bool equipCosmetic(String id) {
    final item = cosmeticById(id);
    if (busy || item == null || !ownedCosmetics.contains(id)) return false;
    if (item.kind == CosmeticKind.bus) {
      if (selectedBus == id) return false;
      selectedBus = id;
    } else {
      if (selectedTerminal == id) return false;
      selectedTerminal = id;
    }
    _track('collection_equip', {'item': id});
    _changed();
    return true;
  }

  Future<void> showDailyRanking() async {
    if (busy || !leaderboards.enabled) return;
    final seed = int.parse(_day(clock().toUtc()).replaceAll('-', ''));
    final score = rankedDailyScores['$seed'];
    var opened = false;
    try {
      opened = await leaderboards.open(
        score == null ? null : DailyScore(seed, score),
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && !_disposed) {
      message = 'Game Center is unavailable. Your personal records are saved.';
      notifyListeners();
    }
  }

  Future<bool> watch(Assist action) async {
    if (!available(action)) {
      return false;
    }
    final epoch = _epoch;
    busy = true;
    _track('ad_request', {'placement': action.name});
    notifyListeners();
    AdOutcome outcome;
    try {
      outcome = await ads.rewarded();
    } catch (_) {
      outcome = AdOutcome.error;
    }
    if (_disposed) {
      return false;
    }
    busy = false;
    if (outcome == AdOutcome.rewarded && epoch == _epoch) {
      _track('ad_reward', {'placement': action.name});
      return _assist(action, paid: false);
    }
    message = outcome == AdOutcome.dismissed
        ? 'Video closed. No coins were spent.'
        : 'Video unavailable. Try again later or use coins.';
    _track('ad_no_reward', {'outcome': outcome.name});
    notifyListeners();
    return false;
  }

  Future<void> buyRemoveAds() async {
    if (busy || removeAds) {
      return;
    }
    busy = true;
    notifyListeners();
    PurchaseOutcome result;
    try {
      result = await purchases.buyRemoveAds();
    } catch (_) {
      result = PurchaseOutcome.error;
    }
    if (_disposed) {
      return;
    }
    busy = false;
    if (result == PurchaseOutcome.purchased) {
      removeAds = true;
      message = 'All automatic ads are removed. Thank you!';
    } else {
      message = switch (result) {
        PurchaseOutcome.cancelled => 'Purchase cancelled.',
        PurchaseOutcome.pending => 'Purchase awaiting approval.',
        _ => 'Store unavailable. No purchase was applied.',
      };
    }
    _track('purchase_result', {'outcome': result.name});
    _changed();
  }

  Future<void> restorePurchases() async {
    if (busy) {
      return;
    }
    busy = true;
    notifyListeners();
    bool? restored;
    try {
      restored = await purchases.restore();
    } catch (_) {
      restored = null;
    }
    if (_disposed) {
      return;
    }
    busy = false;
    if (restored != null) {
      removeAds = restored;
    }
    message = restored == true
        ? 'Purchase restored.'
        : restored == false
        ? 'No active purchase found.'
        : 'Store unavailable. Your current purchase is kept.';
    _track('purchase_restore', {
      'outcome': restored?.toString() ?? 'unavailable',
    });
    _changed();
  }

  void updateEntitlement(bool value) {
    removeAds = value;
    _changed();
  }

  void settings({bool? sound, bool? haptics, bool? reducedMotion}) {
    this.sound = sound ?? this.sound;
    this.haptics = haptics ?? this.haptics;
    this.reducedMotion = reducedMotion ?? this.reducedMotion;
    _changed();
  }

  void finishOnboarding() {
    onboarded = true;
    _changed();
  }

  void lifecycle(String state) {
    analytics.track('lifecycle', {'state': state});
    unawaited(save());
  }

  String? takeMessage() {
    final value = message;
    message = null;
    return value;
  }

  @override
  void dispose() {
    _disposed = true;
    ads.dispose();
    super.dispose();
  }
}
