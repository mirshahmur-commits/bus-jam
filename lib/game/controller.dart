import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../platform/analytics.dart';
import '../platform/monetization.dart';
import '../platform/progress_store.dart';
import 'engine.dart';
import 'generator.dart';
import 'model.dart';

enum Assist { hint, undo, extraSlot }

class GameController extends ChangeNotifier {
  GameController({
    required this.store,
    AnalyticsPort? analytics,
    AdsPort? ads,
    PurchasesPort? purchases,
    DateTime Function()? clock,
  }) : analytics = analytics ?? LocalAnalytics(),
       ads = ads ?? OfflineAds(),
       purchases = purchases ?? OfflinePurchases(),
       clock = clock ?? DateTime.now {
    level = generator.generate(1);
    board = Board.initial(level);
  }
  final ProgressStore store;
  final AnalyticsPort analytics;
  final AdsPort ads;
  final PurchasesPort purchases;
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
  Map<String, dynamic>? _campaign;
  int _epoch = 0;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  Future<void> load() async {
    try {
      final raw = await store.read();
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        if (j['schema'] != 1) {
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
      }
    } catch (_) {
      level = generator.generate(1);
      board = Board.initial(level);
      history = [];
      unlocked = 1;
      coins = 150;
      dailyMode = false;
      _campaign = null;
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
  };
  String snapshot() => jsonEncode({
    'schema': 1,
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

  MoveResult release(int lane) {
    if (busy) {
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
        final day = _day(clock());
        if (completedDay != day &&
            level.seed == int.parse(day.replaceAll('-', ''))) {
          streak =
              completedDay == _day(clock().subtract(const Duration(days: 1)))
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
      totalWins++;
      _track('level_win', {'moves': board.moves, 'reward': reward});
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
    } else {
      level = generator.generate(unlocked);
      board = Board.initial(level);
      history = [];
    }
    hintLane = null;
    lastMove = null;
    _changed();
  }

  int cost(Assist action) => switch (action) {
    Assist.hint => 25,
    Assist.undo => 20,
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
    if (action == Assist.hint) {
      final route = GameEngine.solve(level, board);
      if (route == null || route.isEmpty) {
        message = 'This route is blocked. Undo a move or restart.';
        notifyListeners();
        return false;
      }
      hintLane = route.first;
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
    } else {
      board = GameEngine.continueWithSlot(level, board);
    }
    if (paid) {
      coins -= cost(action);
    }
    _epoch++;
    _track(action.name, {'source': paid ? 'coins' : 'rewarded'});
    _changed();
    return true;
  }

  bool spend(Assist action) => _assist(action, paid: true);
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
