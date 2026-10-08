import 'model.dart';

enum CosmeticKind { bus, terminal }

class Cosmetic {
  const Cosmetic(this.id, this.name, this.description, this.price, this.kind);
  final String id, name, description;
  final int price;
  final CosmeticKind kind;
  // Stable identity for a future verified StoreKit non-consumable. No real
  // purchase is exposed until its product and entitlement adapter are enabled.
  String get productId => 'com.systemcraft.busJam.collection.$id';
}

const cosmetics = <Cosmetic>[
  Cosmetic('classic', 'City Original', 'The fleet that started it all.', 0, CosmeticKind.bus),
  Cosmetic('metro', 'Metro Line', 'Clean silver trim and a city stripe.', 300, CosmeticKind.bus),
  Cosmetic('retro', 'Retro Rider', 'Twin cream stripes. Old-school charm.', 450, CosmeticKind.bus),
  Cosmetic('neon', 'Neon Express', 'Bright rails for the late-night route.', 650, CosmeticKind.bus),
  Cosmetic('royal', 'Golden Ticket', 'Gold accents for your finest dispatch.', 1000, CosmeticKind.bus),
  Cosmetic('terminal-classic', 'City Terminal', 'Your original home stop.', 0, CosmeticKind.terminal),
  Cosmetic('terminal-coast', 'Coastal Stop', 'Sea-blue paving and a fresh horizon.', 500, CosmeticKind.terminal),
  Cosmetic('terminal-garden', 'Garden Stop', 'Soft greens and a leafy terminal.', 750, CosmeticKind.terminal),
  Cosmetic('terminal-night', 'After Hours', 'A navy terminal with glowing markings.', 1000, CosmeticKind.terminal),
];

Cosmetic? cosmeticById(String id) {
  for (final item in cosmetics) {
    if (item.id == id) return item;
  }
  return null;
}

class RouteRecord {
  const RouteRecord({required this.score, required this.stars, required this.parkingCost});
  final int score, stars, parkingCost;
  Map<String, dynamic> toJson() => {'score': score, 'stars': stars, 'parkingCost': parkingCost};
  factory RouteRecord.fromJson(Map<String, dynamic> json) {
    final score = json['score'] as int, stars = json['stars'] as int, cost = json['parkingCost'] as int;
    if (score < 0 || score > 10000 || stars < 1 || stars > 3 || cost < 0 || cost > 10000) throw const FormatException('Invalid route record');
    return RouteRecord(score: score, stars: stars, parkingCost: cost);
  }
}

class RouteResult {
  const RouteResult({required this.score, required this.stars, required this.parkingCost, required this.target, required this.reward, required this.personalBest, required this.ranked});
  final int score, stars, parkingCost, target, reward;
  final bool personalBest, ranked;
  RouteRecord get record => RouteRecord(score: score, stars: stars, parkingCost: parkingCost);
  Map<String, dynamic> toJson() => {...record.toJson(), 'target': target, 'reward': reward, 'personalBest': personalBest, 'ranked': ranked};
  factory RouteResult.fromJson(Map<String, dynamic> json) {
    final record = RouteRecord.fromJson(json);
    return RouteResult(score: record.score, stars: record.stars, parkingCost: record.parkingCost, target: json['target'] as int, reward: json['reward'] as int, personalBest: json['personalBest'] as bool, ranked: json['ranked'] as bool);
  }
}

RouteRecord evaluateRoute(Level level, Board board, {required int parkingCost, required bool usedHint}) {
  if (board.phase(level) != GamePhase.won) throw StateError('Cannot score an unfinished route');
  final excess = (parkingCost - level.parkingTarget).clamp(0, 10000);
  final stars = board.continued ? 1 : (!usedHint && excess == 0 ? 3 : 2);
  final efficiency = (600 - excess * 50).clamp(0, 600);
  final score = 1000 + efficiency + (board.continued ? 0 : 250) + (usedHint ? 0 : 150);
  return RouteRecord(score: score, stars: stars, parkingCost: parkingCost);
}
