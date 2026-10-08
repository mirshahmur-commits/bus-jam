import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DailyScore {
  const DailyScore(this.seed, this.score);
  final int seed, score;
  Map<String, Object> toJson() => {'seed': seed, 'score': score};
}

abstract class LeaderboardsPort {
  bool get enabled;
  Future<bool> submit(DailyScore score);
  Future<bool> open(DailyScore? score);
}

class OfflineLeaderboards implements LeaderboardsPort {
  const OfflineLeaderboards();
  @override
  bool get enabled => false;
  @override
  Future<bool> submit(DailyScore score) async => false;
  @override
  Future<bool> open(DailyScore? score) async => false;
}

class GameCenterLeaderboards implements LeaderboardsPort {
  const GameCenterLeaderboards(this.id);
  final String id;
  static const channel = MethodChannel('com.systemcraft.busjam/rankings');
  @override
  bool get enabled => id.isNotEmpty;
  @override
  Future<bool> submit(DailyScore score) => _call('submit', score);
  @override
  Future<bool> open(DailyScore? score) => _call('show', score);
  Future<bool> _call(String method, DailyScore? score) async {
    if (!enabled ||
        (score != null && (score.score < 0 || score.score > 2000))) {
      return false;
    }
    try {
      return await channel
              .invokeMethod<bool>(method, {
                'leaderboard': id,
                if (score != null) ...score.toJson(),
              })
              .timeout(const Duration(seconds: 30)) ??
          false;
    } catch (_) {
      return false;
    }
  }
}

LeaderboardsPort defaultLeaderboards() {
  const id = String.fromEnvironment('GAME_CENTER_LEADERBOARD_ID');
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && id.isNotEmpty
      ? const GameCenterLeaderboards(id)
      : const OfflineLeaderboards();
}
