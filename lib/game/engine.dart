import 'model.dart';

/// Pure deterministic rules for the crowd puzzle.
class GameEngine {
  /// Walks the passenger at [cell] to the stop. A matching passenger boards
  /// the bus; anyone else takes the next free waiting slot. Full buses leave
  /// and the next bus collects matching waiting passengers in arrival order.
  static MoveResult tap(Level level, Board board, int cell) {
    if (board.phase(level) != GamePhase.playing ||
        cell < 0 ||
        cell >= board.people.length ||
        board.people[cell] < 0 ||
        !board.reachable(level).contains(cell)) {
      return MoveResult(board);
    }
    final path = board.walk(level, cell);
    final people = board.people.toList();
    final color = BusColor.values[people[cell]];
    people[cell] = -1;
    var busIndex = board.busIndex, boarded = board.boarded;
    final waiting = <(BusColor, int)>[
      for (int i = 0; i < board.waiting.length; i++) (board.waiting[i], i),
    ];
    var toBus = false, slot = -1, departures = 0;
    final fromWaiting = <int>[];
    if (level.buses[busIndex] == color) {
      boarded++;
      toBus = true;
    } else {
      slot = waiting.length;
      waiting.add((color, -1));
    }
    while (boarded == busCapacity) {
      busIndex++;
      boarded = 0;
      departures++;
      if (busIndex >= level.buses.length) break;
      final next = level.buses[busIndex];
      for (int i = 0; i < waiting.length && boarded < busCapacity;) {
        if (waiting[i].$1 == next) {
          fromWaiting.add(waiting[i].$2);
          waiting.removeAt(i);
          boarded++;
        } else {
          i++;
        }
      }
    }
    final next = Board(
      people: people,
      waiting: waiting.map((w) => w.$1).toList(),
      busIndex: busIndex,
      boarded: boarded,
      moves: board.moves + 1,
      slots: board.slots,
      continued: board.continued,
    );
    return MoveResult(
      next,
      accepted: true,
      cell: cell,
      path: List.unmodifiable(path),
      toBus: toBus,
      waitingSlot: slot,
      fromWaiting: List.unmodifiable(fromWaiting),
      departures: departures,
    );
  }

  static Board continueWithSlot(Level l, Board b) {
    if (b.phase(l) != GamePhase.failed || b.continued) {
      return b;
    }
    return Board(
      people: b.people,
      waiting: b.waiting,
      busIndex: b.busIndex,
      boarded: b.boarded,
      moves: b.moves,
      slots: b.slots + 1,
      continued: true,
    );
  }

  /// Returns a genuine winning route of cell taps from the current state, or
  /// null for a dead end. Budget exhaustion never produces a fabricated hint.
  /// The solver knows hidden colours; hints never reveal them directly.
  static List<int>? solve(Level level, Board start, {int maxStates = 40000}) {
    final visited = <String>{};
    List<int>? visit(Board b) {
      final phase = b.phase(level);
      if (phase == GamePhase.won) return [];
      if (phase == GamePhase.failed ||
          visited.length >= maxStates ||
          !visited.add(b.searchKey)) {
        return null;
      }
      final wanted = b.currentBus(level)!.index;
      final choices = b.reachable(level).toList()..sort();
      // Matching passengers first; one representative per waiting colour.
      final matching = choices.where((i) => b.people[i] == wanted).toList();
      final tried = <int>{};
      final others = <int>[];
      for (final i in choices) {
        if (b.people[i] != wanted) others.add(i);
      }
      // Prefer passengers whose colour already waits or comes soon.
      int soon(int i) {
        for (int k = b.busIndex; k < level.buses.length; k++) {
          if (level.buses[k].index == b.people[i]) return k - b.busIndex;
        }
        return 99;
      }

      others.sort((a, c) => soon(a).compareTo(soon(c)));
      for (final cell in [...matching, ...others]) {
        if (!tried.add(cell)) continue;
        final result = tap(level, b, cell);
        if (!result.accepted) continue;
        final tail = visit(result.board);
        if (tail != null) return [cell, ...tail];
      }
      return null;
    }

    return visit(start);
  }

  /// Sum of waiting passengers after each move along [route].
  static int waitingCost(Level level, List<int> route) {
    var board = Board.initial(level);
    var cost = 0;
    for (final cell in route) {
      final result = tap(level, board, cell);
      if (!result.accepted) throw StateError('Blocked route');
      board = result.board;
      cost += board.waiting.length;
    }
    return cost;
  }
}
