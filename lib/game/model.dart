import 'dart:convert';

enum BusColor { coral, blue, gold, mint, violet, rose }

enum GamePhase { playing, won, failed }

class Bus {
  const Bus(this.id, this.color, {this.capacity = 3, this.boarded = 0});
  final int id;
  final BusColor color;
  final int capacity;
  final int boarded;
  Bus board() => Bus(id, color, capacity: capacity, boarded: boarded + 1);
  Map<String, dynamic> toJson() => {
    'id': id,
    'color': color.index,
    'capacity': capacity,
    'boarded': boarded,
  };
  factory Bus.fromJson(Map<String, dynamic> j) => Bus(
    j['id'] as int,
    BusColor.values[j['color'] as int],
    capacity: j['capacity'] as int,
    boarded: j['boarded'] as int,
  );
}

class Level {
  Level({
    required this.number,
    required this.seed,
    required List<List<Bus>> lanes,
    required List<BusColor> passengers,
    this.slots = 3,
    List<int> solution = const [],
    this.generatorVersion = 1,
    this.title = 'City route',
    this.lesson = 'Keep a space open for the next bus.',
    this.parkingTarget = 0,
    this.hard = false,
  }) : lanes = List.unmodifiable(lanes.map((e) => List<Bus>.unmodifiable(e))),
       passengers = List.unmodifiable(passengers),
       solution = List.unmodifiable(solution) {
    if (number < 1 ||
        slots < 1 ||
        slots > 4 ||
        lanes.isEmpty ||
        lanes.length > 4 ||
        parkingTarget < 0 ||
        (generatorVersion != 1 && generatorVersion != 2) ||
        passengers.isEmpty) {
      throw const FormatException('Invalid level dimensions');
    }
    final ids = <int>{};
    final supply = List.filled(BusColor.values.length, 0);
    final demand = List.filled(BusColor.values.length, 0);
    for (final bus in lanes.expand((e) => e)) {
      if (!ids.add(bus.id) ||
          bus.capacity < 1 ||
          bus.capacity > 8 ||
          bus.boarded != 0) {
        throw const FormatException('Invalid bus');
      }
      supply[bus.color.index] += bus.capacity;
    }
    for (final color in passengers) {
      demand[color.index]++;
    }
    if (jsonEncode(supply) != jsonEncode(demand)) {
      throw const FormatException(
        'Passenger and seat counts must match by color',
      );
    }
  }
  final int number, seed, slots, generatorVersion;
  final String title, lesson;
  final int parkingTarget;
  final bool hard;
  final List<List<Bus>> lanes;
  final List<BusColor> passengers;
  final List<int> solution;
  int get busCount => lanes.fold(0, (n, lane) => n + lane.length);
  String get district => [
    'SUNNY SQUARE',
    'COASTAL DRIVE',
    'GARDEN LOOP',
    'SUNSET CITY',
  ][((number - 1) ~/ 10) % 4];
  Map<String, dynamic> toJson() => {
    'number': number,
    'seed': seed,
    'slots': slots,
    'version': generatorVersion,
    'lanes': lanes.map((l) => l.map((b) => b.toJson()).toList()).toList(),
    'passengers': passengers.map((c) => c.index).toList(),
    'solution': solution,
    'title': title,
    'lesson': lesson,
    'parkingTarget': parkingTarget,
    'hard': hard,
  };
  factory Level.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1 && j['version'] != 2) {
      throw const FormatException('Unsupported generator version');
    }
    return Level(
      number: j['number'] as int,
      seed: j['seed'] as int,
      generatorVersion: j['version'] as int,
      slots: j['slots'] as int,
      lanes: (j['lanes'] as List)
          .map(
            (l) => (l as List)
                .map((b) => Bus.fromJson(Map<String, dynamic>.from(b as Map)))
                .toList(),
          )
          .toList(),
      passengers: (j['passengers'] as List)
          .map((c) => BusColor.values[c as int])
          .toList(),
      solution: (j['solution'] as List).cast<int>(),
      title: j['title'] as String? ?? 'City route',
      lesson: j['lesson'] as String? ?? 'Keep a space open for the next bus.',
      parkingTarget: j['parkingTarget'] as int? ?? 0,
      hard: j['hard'] as bool? ?? false,
    );
  }
}

class Board {
  Board({
    required List<List<Bus>> lanes,
    required List<Bus> parked,
    required this.cursor,
    required this.departed,
    required this.moves,
    required this.slots,
    this.continued = false,
  }) : lanes = List.unmodifiable(lanes.map((l) => List<Bus>.unmodifiable(l))),
       parked = List.unmodifiable(parked);
  factory Board.initial(Level l) => Board(
    lanes: l.lanes,
    parked: [],
    cursor: 0,
    departed: 0,
    moves: 0,
    slots: l.slots,
  );
  final List<List<Bus>> lanes;
  final List<Bus> parked;
  final int cursor, departed, moves, slots;
  final bool continued;
  GamePhase phase(Level l) {
    if (cursor == l.passengers.length &&
        parked.isEmpty &&
        lanes.every((l) => l.isEmpty)) {
      return GamePhase.won;
    }
    if (parked.length >= slots || lanes.every((l) => l.isEmpty)) {
      return GamePhase.failed;
    }
    return GamePhase.playing;
  }

  Map<String, dynamic> toJson() => {
    'lanes': lanes.map((l) => l.map((b) => b.toJson()).toList()).toList(),
    'parked': parked.map((b) => b.toJson()).toList(),
    'cursor': cursor,
    'departed': departed,
    'moves': moves,
    'slots': slots,
    'continued': continued,
  };
  factory Board.fromJson(Map<String, dynamic> j, Level level) {
    final b = Board(
      lanes: (j['lanes'] as List)
          .map(
            (l) => (l as List)
                .map((b) => Bus.fromJson(Map<String, dynamic>.from(b as Map)))
                .toList(),
          )
          .toList(),
      parked: (j['parked'] as List)
          .map((b) => Bus.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList(),
      cursor: j['cursor'] as int,
      departed: j['departed'] as int,
      moves: j['moves'] as int,
      slots: j['slots'] as int,
      continued: j['continued'] as bool,
    );
    b.validate(level);
    return b;
  }
  void validate(Level l) {
    if (cursor < 0 ||
        cursor > l.passengers.length ||
        moves < 0 ||
        departed < 0 ||
        slots != l.slots + (continued ? 1 : 0) ||
        parked.length > slots ||
        lanes.length != l.lanes.length) {
      throw const FormatException('Invalid board dimensions');
    }
    final original = {for (final bus in l.lanes.expand((x) => x)) bus.id: bus};
    final seen = <int>{};
    final remaining = List.filled(BusColor.values.length, 0);
    for (final bus in [...lanes.expand((x) => x), ...parked]) {
      final origin = original[bus.id];
      if (!seen.add(bus.id) ||
          origin == null ||
          origin.color != bus.color ||
          origin.capacity != bus.capacity ||
          bus.boarded < 0 ||
          bus.boarded >= bus.capacity) {
        throw const FormatException('Invalid or duplicate bus in save');
      }
      remaining[bus.color.index] += bus.capacity - bus.boarded;
    }
    for (int i = 0; i < lanes.length; i++) {
      final ids = l.lanes[i].map((b) => b.id).toList();
      final current = lanes[i].map((b) => b.id).toList();
      if (lanes[i].any((b) => b.boarded != 0) ||
          jsonEncode(ids.skip(ids.length - current.length).toList()) !=
              jsonEncode(current)) {
        throw const FormatException('Invalid lane order');
      }
    }
    final demand = List.filled(BusColor.values.length, 0);
    for (final c in l.passengers.skip(cursor)) {
      demand[c.index]++;
    }
    if (jsonEncode(remaining) != jsonEncode(demand) ||
        departed + seen.length != original.length ||
        moves != parked.length + departed) {
      throw const FormatException('Save violates conservation');
    }
    if (cursor < l.passengers.length &&
        parked.any((b) => b.color == l.passengers[cursor])) {
      throw const FormatException('Unsettled save');
    }
  }

  String get searchKey =>
      '${lanes.map((l) => l.length).join(',')}:$cursor:${parked.map((b) => '${b.id}/${b.boarded}').join(',')}:$slots';
}

class Boarding {
  const Boarding(this.passenger, this.busId, this.color);
  final int passenger, busId;
  final BusColor color;
}

class MoveResult {
  const MoveResult(
    this.board, {
    this.accepted = false,
    this.boarding = const [],
    this.departures = const [],
  });
  final Board board;
  final bool accepted;
  final List<Boarding> boarding;
  final List<Bus> departures;
}
