import 'dart:convert';

enum BusColor { coral, blue, gold, mint, violet, rose }

enum GamePhase { playing, won, failed }

/// Every bus seats three passengers.
const busCapacity = 3;

/// A bus as drawn on screen. Puzzle content is the colour sequence in [Level].
class Bus {
  const Bus(
    this.id,
    this.color, {
    this.capacity = busCapacity,
    this.boarded = 0,
  });
  final int id;
  final BusColor color;
  final int capacity;
  final int boarded;
}

/// A crowd puzzle. Passengers queue in [lanes] that stream up to the stop;
/// only the front passenger of a lane can walk. Buses arrive one at a time
/// in [buses] order.
class Level {
  Level({
    required this.number,
    required this.seed,
    required List<List<int>> lanes,
    required List<BusColor> buses,
    Set<int> hidden = const {},
    this.slots = 5,
    List<int> solution = const [],
    this.generatorVersion = 3,
    this.title = 'City stop',
    this.lesson = 'Tap a lane to send its front passenger.',
    this.parkingTarget = 0,
    this.hard = false,
  }) : lanes = List.unmodifiable(lanes.map((l) => List<int>.unmodifiable(l))),
       buses = List.unmodifiable(buses),
       hidden = Set.unmodifiable(hidden),
       solution = List.unmodifiable(solution) {
    if (number < 1 ||
        lanes.isEmpty ||
        lanes.length > 6 ||
        lanes.any((l) => l.isEmpty || l.length > 40) ||
        slots < 1 ||
        slots > 7 ||
        buses.isEmpty ||
        parkingTarget < 0 ||
        generatorVersion != 3) {
      throw const FormatException('Invalid level dimensions');
    }
    final demand = List.filled(BusColor.values.length, 0);
    final supply = List.filled(BusColor.values.length, 0);
    for (final color in lanes.expand((l) => l)) {
      if (color < 0 || color >= BusColor.values.length) {
        throw const FormatException('Invalid passenger');
      }
      demand[color]++;
    }
    for (final bus in buses) {
      supply[bus.index] += busCapacity;
    }
    if (jsonEncode(supply) != jsonEncode(demand)) {
      throw const FormatException(
        'Passenger and seat counts must match by color',
      );
    }
    if (hidden.any(
      (k) =>
          k ~/ 1000 >= lanes.length ||
          k % 1000 == 0 ||
          k % 1000 >= lanes[k ~/ 1000].length,
    )) {
      throw const FormatException('Invalid hidden passenger');
    }
  }
  final int number, seed, slots, generatorVersion;
  final String title, lesson;
  final int parkingTarget;
  final bool hard;

  /// Colour index per passenger, front of each lane first.
  final List<List<int>> lanes;
  final List<BusColor> buses;

  /// Passengers (`lane * 1000 + depth`) whose colour stays secret until they
  /// reach the front of their lane. Front passengers are never hidden.
  final Set<int> hidden;

  /// Lane taps of a verified winning route.
  final List<int> solution;
  static int key(int lane, int depth) => lane * 1000 + depth;
  bool isHidden(int lane, int depth) => hidden.contains(key(lane, depth));
  int get busCount => buses.length;
  int get passengerCount => buses.length * busCapacity;
  String get district => [
    'SUNNY SQUARE',
    'COASTAL DRIVE',
    'GARDEN LOOP',
    'SUNSET CITY',
  ][((number - 1) ~/ 10) % 4];
  Map<String, dynamic> toJson() => {
    'number': number,
    'seed': seed,
    'version': generatorVersion,
    'lanes': lanes,
    'buses': buses.map((c) => c.index).toList(),
    'hidden': hidden.toList()..sort(),
    'slots': slots,
    'solution': solution,
    'title': title,
    'lesson': lesson,
    'parkingTarget': parkingTarget,
    'hard': hard,
  };
  factory Level.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 3) {
      throw const FormatException('Unsupported generator version');
    }
    return Level(
      number: j['number'] as int,
      seed: j['seed'] as int,
      lanes: (j['lanes'] as List).map((l) => (l as List).cast<int>()).toList(),
      buses: (j['buses'] as List)
          .map((c) => BusColor.values[c as int])
          .toList(),
      hidden: (j['hidden'] as List).cast<int>().toSet(),
      slots: j['slots'] as int,
      solution: (j['solution'] as List).cast<int>(),
      title: j['title'] as String? ?? 'City stop',
      lesson: j['lesson'] as String? ?? '',
      parkingTarget: j['parkingTarget'] as int? ?? 0,
      hard: j['hard'] as bool? ?? false,
    );
  }
}

class Board {
  Board({
    required List<int> taken,
    required List<BusColor> waiting,
    required this.busIndex,
    required this.boarded,
    required this.moves,
    required this.slots,
    this.continued = false,
  }) : taken = List.unmodifiable(taken),
       waiting = List.unmodifiable(waiting);
  factory Board.initial(Level l) => Board(
    taken: List.filled(l.lanes.length, 0),
    waiting: const [],
    busIndex: 0,
    boarded: 0,
    moves: 0,
    slots: l.slots,
  );

  /// Passengers that have already left each lane.
  final List<int> taken;

  /// Passengers in the waiting slots, in arrival order.
  final List<BusColor> waiting;

  /// Index of the bus at the stop and passengers already seated in it.
  final int busIndex, boarded, moves, slots;
  final bool continued;
  int remaining(Level l) {
    var n = 0;
    for (int i = 0; i < taken.length; i++) {
      n += l.lanes[i].length - taken[i];
    }
    return n;
  }

  bool open(Level l, int lane) =>
      lane >= 0 && lane < taken.length && taken[lane] < l.lanes[lane].length;

  /// Colour of the front passenger of [lane], or null for an empty lane.
  int? front(Level l, int lane) =>
      open(l, lane) ? l.lanes[lane][taken[lane]] : null;

  GamePhase phase(Level l) {
    if (busIndex >= l.buses.length) return GamePhase.won;
    if (waiting.length >= slots) return GamePhase.failed;
    return GamePhase.playing;
  }

  BusColor? currentBus(Level l) =>
      busIndex < l.buses.length ? l.buses[busIndex] : null;

  Map<String, dynamic> toJson() => {
    'taken': taken,
    'waiting': waiting.map((c) => c.index).toList(),
    'bus': busIndex,
    'boarded': boarded,
    'moves': moves,
    'slots': slots,
    'continued': continued,
  };
  factory Board.fromJson(Map<String, dynamic> j, Level level) {
    final b = Board(
      taken: (j['taken'] as List).cast<int>(),
      waiting: (j['waiting'] as List)
          .map((c) => BusColor.values[c as int])
          .toList(),
      busIndex: j['bus'] as int,
      boarded: j['boarded'] as int,
      moves: j['moves'] as int,
      slots: j['slots'] as int,
      continued: j['continued'] as bool,
    );
    b.validate(level);
    return b;
  }

  /// Rejects saves that break passenger conservation or settled boarding.
  void validate(Level l) {
    if (taken.length != l.lanes.length ||
        busIndex < 0 ||
        busIndex > l.buses.length ||
        boarded < 0 ||
        boarded >= busCapacity ||
        (busIndex == l.buses.length && boarded != 0) ||
        moves < 0 ||
        slots != l.slots + (continued ? 1 : 0) ||
        waiting.length > slots) {
      throw const FormatException('Invalid board dimensions');
    }
    final left = List.filled(BusColor.values.length, 0);
    var count = 0;
    for (int i = 0; i < taken.length; i++) {
      if (taken[i] < 0 || taken[i] > l.lanes[i].length) {
        throw const FormatException('Invalid lane progress');
      }
      for (int d = 0; d < taken[i]; d++) {
        left[l.lanes[i][d]]++;
      }
      count += taken[i];
    }
    final seated = List.filled(BusColor.values.length, 0);
    for (int b = 0; b < busIndex; b++) {
      seated[l.buses[b].index] += busCapacity;
    }
    if (busIndex < l.buses.length) seated[l.buses[busIndex].index] += boarded;
    for (final w in waiting) {
      seated[w.index]++;
    }
    if (jsonEncode(left) != jsonEncode(seated) || moves != count) {
      throw const FormatException('Save violates conservation');
    }
    final bus = currentBus(l);
    if (bus != null && waiting.contains(bus)) {
      throw const FormatException('Unsettled save');
    }
  }

  String get searchKey =>
      '${taken.join(',')}:${(waiting.map((c) => c.index).toList()..sort()).join()}:$slots';
}

class MoveResult {
  const MoveResult(
    this.board, {
    this.accepted = false,
    this.lane = -1,
    this.color,
    this.toBus = false,
    this.seat = -1,
    this.waitingSlot = -1,
    this.fromWaiting = const [],
    this.departures = 0,
  });
  final Board board;
  final bool accepted;

  /// Tapped lane and the colour of the passenger who left it.
  final int lane;
  final BusColor? color;

  /// Whether the passenger boarded directly (and their seat), or the
  /// waiting slot they took.
  final bool toBus;
  final int seat, waitingSlot;

  /// Waiting slots (indices before the move) whose passengers boarded the
  /// buses that pulled in after this move, in boarding order.
  final List<int> fromWaiting;
  final int departures;
}
