import 'model.dart';

/// Consumable power-ups used during an endless rush.
enum Booster { rainbow, slow, taxi }

/// Permanent upgrades bought with coins.
enum Upgrade { bigBus, wideStop, calmCrowd }

const boosterPrices = {Booster.rainbow: 60, Booster.slow: 40, Booster.taxi: 50};
const boosterSeconds = {Booster.rainbow: 30, Booster.slow: 20, Booster.taxi: 0};

/// Price of the next level of [u] after [level] levels, or null at max.
int? upgradePrice(Upgrade u, int level) {
  const prices = {
    Upgrade.bigBus: [300, 700, 1500],
    Upgrade.wideStop: [400, 1000],
    Upgrade.calmCrowd: [250, 600],
  };
  final list = prices[u]!;
  return level < list.length ? list[level] : null;
}

int upgradeMax(Upgrade u) => switch (u) {
  Upgrade.bigBus => 3,
  Upgrade.wideStop => 2,
  Upgrade.calmCrowd => 2,
};

/// Settings for one rush, derived from the player's upgrades.
class RushConfig {
  const RushConfig({
    this.capacity = busCapacity,
    this.slots = 5,
    this.startInterval = 1300,
    this.lanes = 4,
    this.laneCap = 10,
    this.seed = 1,
  });
  factory RushConfig.fromUpgrades(Map<Upgrade, int> levels, int seed) =>
      RushConfig(
        capacity: busCapacity + (levels[Upgrade.bigBus] ?? 0),
        slots: 5 + (levels[Upgrade.wideStop] ?? 0),
        startInterval: 1300 + 250 * (levels[Upgrade.calmCrowd] ?? 0),
        seed: seed,
      );
  final int capacity, slots, startInterval, lanes, laneCap, seed;
}

enum RushEnd { none, slotsFull, overflow }

/// Result of one tap, for animation and sound.
class RushMove {
  const RushMove({
    this.accepted = false,
    this.lane = -1,
    this.color,
    this.toBus = false,
    this.seat = -1,
    this.waitingSlot = -1,
    this.fromWaiting = const [],
    this.departed = const [],
    this.points = 0,
  });
  final bool accepted, toBus;
  final int lane, seat, waitingSlot, points;
  final BusColor? color;

  /// Waiting slots (indices before the move) that boarded afterwards.
  final List<int> fromWaiting;

  /// Colours of buses that left, in order.
  final List<BusColor> departed;
}

/// Endless rush: passengers never stop arriving and the pace keeps rising.
/// Score as many passengers as possible before the stop jams (every waiting
/// slot taken) or the crowd overflows (no lane has room for a newcomer).
///
/// Fairness: every bus added to the line puts exactly its seats' colours
/// into the arrival bag, and passengers are drawn from the front of that bag
/// (about two buses ahead). Every passenger therefore has a seat on a bus
/// that is already scheduled, and arrivals roughly follow the bus order.
class EndlessRun {
  EndlessRun(this.config)
    : _rng = ((config.seed * 2654435761) & 0xFFFFFFFF) | 1 {
    // Warm up so neighbouring seeds diverge immediately.
    for (int i = 0; i < 16; i++) {
      _next(2);
    }
    for (int i = 0; i < config.lanes; i++) {
      lanes.add([]);
    }
    for (int i = 0; i < 3; i++) {
      _enqueueBus();
    }
    // Opening crowd: seven per lane, so the corridor starts busy.
    for (int i = 0; i < config.lanes * 7; i++) {
      _spawn(i % config.lanes);
    }
    nextSpawn = interval;
  }
  final RushConfig config;
  int _rng;
  final lanes = <List<BusColor>>[];
  final waiting = <BusColor>[];

  /// Buses still to come, the first being at the stop.
  final buses = <BusColor>[];
  final _bag = <BusColor>[];
  int boarded = 0, clock = 0, nextSpawn = 0;
  int score = 0, delivered = 0, busesSent = 0, streak = 0;
  int rainbowUntil = 0, slowUntil = 0;
  int extraSlots = 0;
  RushEnd end = RushEnd.none;
  bool get over => end != RushEnd.none;
  int get slots => config.slots + extraSlots;
  BusColor get bus => buses.first;
  BusColor? get nextBus => buses.length > 1 ? buses[1] : null;
  bool get rainbow => clock < rainbowUntil;
  bool get slow => clock < slowUntil;
  int get colours => (4 + busesSent ~/ 12).clamp(4, 6);

  /// Milliseconds between arrivals: faster with every bus sent and every
  /// second played.
  int get interval {
    final base = (config.startInterval - busesSent * 18 - clock ~/ 400).clamp(
      380,
      5000,
    );
    return slow ? base * 2 : base;
  }

  int _next(int n) {
    // xorshift32: small, deterministic and serialisable.
    var x = _rng;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _rng = x & 0xFFFFFFFF;
    return _rng % n;
  }

  void _enqueueBus() {
    var colour = BusColor.values[_next(colours)];
    if (buses.length >= 2 &&
        buses[buses.length - 1] == colour &&
        buses[buses.length - 2] == colour) {
      colour = BusColor.values[(colour.index + 1) % colours];
    }
    buses.add(colour);
    final owed = (_owed[colour] ?? 0).clamp(0, config.capacity);
    _owed[colour] = (_owed[colour] ?? 0) - owed;
    _bag.addAll(List.filled(config.capacity - owed, colour));
  }

  /// Seats owed to passengers who already exist without one (after a
  /// rainbow boarding used their seat).
  final _owed = <BusColor, int>{};

  /// Keeps every passenger matched to exactly one scheduled seat when
  /// [rider] takes a seat meant for [seat], or leaves without one.
  void _rebalance(BusColor rider, BusColor? seat) {
    if (rider == seat) return;
    // The rider's own seat is now free: a newcomer of that colour fills it.
    _bag.add(rider);
    if (seat == null) return;
    // Someone of the seat's colour lost their seat.
    final i = _bag.indexOf(seat);
    if (i >= 0) {
      _bag.removeAt(i);
    } else {
      _owed[seat] = (_owed[seat] ?? 0) + 1;
    }
  }

  /// Adds one arriving passenger to [preferred] lane, or the shortest lane
  /// with room. Returns the lane used, or -1 when every lane is full.
  int _spawn(int preferred) {
    var lane = preferred;
    if (lanes[lane].length >= config.laneCap) {
      lane = -1;
      for (int i = 0; i < lanes.length; i++) {
        if (lanes[i].length < config.laneCap &&
            (lane < 0 || lanes[i].length < lanes[lane].length)) {
          lane = i;
        }
      }
      if (lane < 0) return -1;
    }
    while (_bag.isEmpty) {
      _enqueueBus();
    }
    // Arrivals follow the bus order with a local shuffle: draw from the
    // seats of roughly the next two buses only.
    final window = _bag.length.clamp(1, config.capacity * 2);
    lanes[lane].add(_bag.removeAt(_next(window)));
    return lane;
  }

  /// Advances time by [ms]; returns the lanes that received newcomers.
  List<int> advance(int ms) {
    final arrived = <int>[];
    if (over || ms <= 0) return arrived;
    final until = clock + ms;
    while (nextSpawn <= until && !over) {
      clock = nextSpawn;
      final lane = _spawn(_next(lanes.length));
      if (lane < 0) {
        end = RushEnd.overflow;
        return arrived;
      }
      arrived.add(lane);
      nextSpawn = clock + interval;
    }
    clock = until;
    return arrived;
  }

  bool _matches(BusColor c) => c == bus || rainbow;

  RushMove tap(int lane) {
    if (over || lane < 0 || lane >= lanes.length || lanes[lane].isEmpty) {
      return const RushMove();
    }
    final color = lanes[lane].removeAt(0);
    var toBus = false, seat = -1, slot = -1, points = 0;
    if (_matches(color)) {
      _rebalance(color, bus);
      seat = boarded;
      boarded++;
      toBus = true;
      streak++;
      points += 10 + 2 * (streak - 1).clamp(0, 10);
      delivered++;
    } else {
      streak = 0;
      slot = waiting.length;
      waiting.add(color);
    }
    final settle = _settle();
    points += settle.$3;
    score += points;
    if (waiting.length >= slots) end = RushEnd.slotsFull;
    return RushMove(
      accepted: true,
      lane: lane,
      color: color,
      toBus: toBus,
      seat: seat,
      waitingSlot: slot,
      fromWaiting: settle.$1,
      departed: settle.$2,
      points: points,
    );
  }

  /// Sends full buses away and seats matching waiting passengers.
  (List<int>, List<BusColor>, int) _settle() {
    final fromWaiting = <int>[];
    final departed = <BusColor>[];
    var points = 0;
    final ids = [for (int i = 0; i < waiting.length; i++) i];
    void board() {
      for (int i = 0; i < waiting.length && boarded < config.capacity;) {
        if (_matches(waiting[i])) {
          _rebalance(waiting[i], bus);
          fromWaiting.add(ids[i]);
          waiting.removeAt(i);
          ids.removeAt(i);
          boarded++;
          delivered++;
          points += 5;
        } else {
          i++;
        }
      }
    }

    board();
    while (boarded >= config.capacity) {
      departed.add(buses.removeAt(0));
      busesSent++;
      boarded = 0;
      points += 25;
      if (buses.length < 3 || _bag.isEmpty) _enqueueBus();
      board();
    }
    return (fromWaiting, departed, points);
  }

  /// Applies a booster. Taxi takes every waiting passenger away.
  RushMove? use(Booster b) {
    if (over && !(b == Booster.taxi && end == RushEnd.slotsFull)) return null;
    switch (b) {
      case Booster.rainbow:
        rainbowUntil = clock + boosterSeconds[b]! * 1000;
        final settle = _settle();
        score += settle.$3;
        return RushMove(
          accepted: true,
          fromWaiting: settle.$1,
          departed: settle.$2,
          points: settle.$3,
        );
      case Booster.slow:
        slowUntil = clock + boosterSeconds[b]! * 1000;
        nextSpawn = clock + interval;
        return const RushMove(accepted: true);
      case Booster.taxi:
        if (waiting.isEmpty) return null;
        final gone = waiting.length;
        // Their seats are refilled by newcomers of the same colours.
        for (final rider in waiting) {
          _rebalance(rider, null);
        }
        waiting.clear();
        delivered += gone;
        score += gone * 5;
        if (end == RushEnd.slotsFull) end = RushEnd.none;
        return RushMove(accepted: true, points: gone * 5);
    }
  }

  /// One extra waiting slot for this run (continue after a jam).
  bool addSlot() {
    if (extraSlots > 0 || end == RushEnd.overflow) return false;
    extraSlots++;
    if (end == RushEnd.slotsFull && waiting.length < slots) {
      end = RushEnd.none;
    }
    return true;
  }

  /// Remaining seats minus passengers by colour; all zero while fair.
  /// Exposed for tests.
  Map<BusColor, int> seatBalance() {
    final balance = {for (final c in BusColor.values) c: 0};
    for (int i = 0; i < buses.length; i++) {
      balance[buses[i]] =
          balance[buses[i]]! + config.capacity - (i == 0 ? boarded : 0);
    }
    for (final c in [...lanes.expand((l) => l), ...waiting, ..._bag]) {
      balance[c] = balance[c]! - 1;
    }
    _owed.forEach((c, n) => balance[c] = balance[c]! + n);
    return balance;
  }

  /// Coins earned for a finished run.
  int get coins => score ~/ 50;
}
