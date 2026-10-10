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

/// A crowd puzzle. Passengers stand on a [rows] x [cols] grid; row 0 touches
/// the bus stop. Only a passenger with a clear path to the stop can walk.
/// Buses arrive one at a time in [buses] order.
class Level {
  Level({
    required this.number,
    required this.seed,
    required this.rows,
    required this.cols,
    required List<int> cells,
    required List<BusColor> buses,
    Set<int> hidden = const {},
    this.slots = 5,
    List<int> solution = const [],
    this.generatorVersion = 3,
    this.title = 'City stop',
    this.lesson = 'Tap a passenger with a clear path to the bus.',
    this.parkingTarget = 0,
    this.hard = false,
  }) : cells = List.unmodifiable(cells),
       buses = List.unmodifiable(buses),
       hidden = Set.unmodifiable(hidden),
       solution = List.unmodifiable(solution) {
    if (number < 1 ||
        rows < 1 ||
        rows > 10 ||
        cols < 1 ||
        cols > 8 ||
        cells.length != rows * cols ||
        slots < 1 ||
        slots > 7 ||
        buses.isEmpty ||
        parkingTarget < 0 ||
        generatorVersion != 3) {
      throw const FormatException('Invalid level dimensions');
    }
    final demand = List.filled(BusColor.values.length, 0);
    final supply = List.filled(BusColor.values.length, 0);
    for (final cell in cells) {
      if (cell < -1 || cell >= BusColor.values.length) {
        throw const FormatException('Invalid passenger');
      }
      if (cell >= 0) demand[cell]++;
    }
    for (final bus in buses) {
      supply[bus.index] += busCapacity;
    }
    if (jsonEncode(supply) != jsonEncode(demand)) {
      throw const FormatException(
        'Passenger and seat counts must match by color',
      );
    }
    if (hidden.any((i) => i < 0 || i >= cells.length || cells[i] < 0)) {
      throw const FormatException('Invalid hidden passenger');
    }
  }
  final int number, seed, rows, cols, slots, generatorVersion;
  final String title, lesson;
  final int parkingTarget;
  final bool hard;

  /// Colour index per cell, or -1 for open pavement.
  final List<int> cells;
  final List<BusColor> buses;

  /// Passengers whose colour stays secret until they can reach the stop.
  final Set<int> hidden;

  /// Cell taps of a verified winning route.
  final List<int> solution;
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
    'rows': rows,
    'cols': cols,
    'cells': cells,
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
      rows: j['rows'] as int,
      cols: j['cols'] as int,
      cells: (j['cells'] as List).cast<int>(),
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
    required List<int> people,
    required List<BusColor> waiting,
    required this.busIndex,
    required this.boarded,
    required this.moves,
    required this.slots,
    this.continued = false,
  }) : people = List.unmodifiable(people),
       waiting = List.unmodifiable(waiting);
  factory Board.initial(Level l) => Board(
    people: l.cells,
    waiting: const [],
    busIndex: 0,
    boarded: 0,
    moves: 0,
    slots: l.slots,
  );

  /// Remaining passengers by cell: colour index, or -1 once they have left.
  final List<int> people;

  /// Passengers in the waiting area, in arrival order.
  final List<BusColor> waiting;

  /// Index of the bus at the stop and passengers already seated in it.
  final int busIndex, boarded, moves, slots;
  final bool continued;
  int get remaining => people.where((p) => p >= 0).length;
  GamePhase phase(Level l) {
    if (busIndex >= l.buses.length) return GamePhase.won;
    if (waiting.length >= slots) return GamePhase.failed;
    return GamePhase.playing;
  }

  BusColor? currentBus(Level l) =>
      busIndex < l.buses.length ? l.buses[busIndex] : null;

  /// Cells that have a clear walk to the stop: row 0, or next to open
  /// pavement that is itself connected to row 0.
  Set<int> reachable(Level l) {
    final open = <int>{};
    final queue = <int>[];
    for (int c = 0; c < l.cols; c++) {
      if (people[c] < 0) {
        open.add(c);
        queue.add(c);
      }
    }
    final result = <int>{
      for (int c = 0; c < l.cols; c++)
        if (people[c] >= 0) c,
    };
    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      for (final n in neighbours(l, i)) {
        if (people[n] >= 0) {
          result.add(n);
        } else if (open.add(n)) {
          queue.add(n);
        }
      }
    }
    return result;
  }

  /// Shortest walk from [cell] through open pavement to row 0, inclusive.
  List<int> walk(Level l, int cell) {
    final previous = <int, int>{cell: cell};
    final queue = [cell];
    for (int head = 0; head < queue.length; head++) {
      final i = queue[head];
      if (i < l.cols) {
        final path = [i];
        var at = i;
        while (at != cell) {
          at = previous[at]!;
          path.add(at);
        }
        return path.reversed.toList();
      }
      for (final n in neighbours(l, i)) {
        if (people[n] < 0 && !previous.containsKey(n)) {
          previous[n] = i;
          queue.add(n);
        }
      }
    }
    return [cell];
  }

  static List<int> neighbours(Level l, int i) {
    final r = i ~/ l.cols, c = i % l.cols;
    return [
      if (r > 0) i - l.cols,
      if (r < l.rows - 1) i + l.cols,
      if (c > 0) i - 1,
      if (c < l.cols - 1) i + 1,
    ];
  }

  Map<String, dynamic> toJson() => {
    'people': people,
    'waiting': waiting.map((c) => c.index).toList(),
    'bus': busIndex,
    'boarded': boarded,
    'moves': moves,
    'slots': slots,
    'continued': continued,
  };
  factory Board.fromJson(Map<String, dynamic> j, Level level) {
    final b = Board(
      people: (j['people'] as List).cast<int>(),
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
    if (people.length != l.cells.length ||
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
    for (int i = 0; i < people.length; i++) {
      if (people[i] >= 0 && people[i] != l.cells[i]) {
        throw const FormatException('Passenger changed colour');
      }
      if (people[i] < 0 && l.cells[i] >= 0) left[l.cells[i]]++;
    }
    final seated = List.filled(BusColor.values.length, 0);
    for (int b = 0; b < busIndex; b++) {
      seated[l.buses[b].index] += busCapacity;
    }
    if (busIndex < l.buses.length) seated[l.buses[busIndex].index] += boarded;
    for (final w in waiting) {
      seated[w.index]++;
    }
    if (jsonEncode(left) != jsonEncode(seated) ||
        moves != l.cells.where((c) => c >= 0).length - remaining) {
      throw const FormatException('Save violates conservation');
    }
    final bus = currentBus(l);
    if (bus != null && waiting.contains(bus)) {
      throw const FormatException('Unsettled save');
    }
  }

  String get searchKey =>
      '${people.map((p) => p < 0 ? '.' : '#').join()}:${(waiting.map((c) => c.index).toList()..sort()).join()}:$slots';
}

class MoveResult {
  const MoveResult(
    this.board, {
    this.accepted = false,
    this.cell = -1,
    this.path = const [],
    this.toBus = false,
    this.waitingSlot = -1,
    this.fromWaiting = const [],
    this.departures = 0,
  });
  final Board board;
  final bool accepted;

  /// Tapped cell and its walk to the stop.
  final int cell;
  final List<int> path;

  /// Whether the passenger boarded directly, or the waiting slot they took.
  final bool toBus;
  final int waitingSlot;

  /// Waiting slots (indices before the move) whose passengers boarded later.
  final List<int> fromWaiting;
  final int departures;
}
