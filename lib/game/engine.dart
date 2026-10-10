import 'model.dart';

/// Pure deterministic rules for the crowd puzzle.
class GameEngine {
  /// Sends the front passenger of [lane] to the stop. A matching passenger
  /// boards the bus; anyone else takes the next free waiting slot. Full buses
  /// leave and the next bus collects matching waiting passengers by itself.
  static MoveResult tap(Level level, Board board, int lane) {
    if (board.phase(level) != GamePhase.playing || !board.open(level, lane)) {
      return MoveResult(board);
    }
    final color = BusColor.values[board.front(level, lane)!];
    final taken = board.taken.toList();
    taken[lane]++;
    var busIndex = board.busIndex, boarded = board.boarded;
    final waiting = <(BusColor, int)>[
      for (int i = 0; i < board.waiting.length; i++) (board.waiting[i], i),
    ];
    var toBus = false, seat = -1, slot = -1, departures = 0;
    final fromWaiting = <int>[];
    if (level.buses[busIndex] == color) {
      seat = boarded;
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
      taken: taken,
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
      lane: lane,
      color: color,
      toBus: toBus,
      seat: seat,
      waitingSlot: slot,
      fromWaiting: List.unmodifiable(fromWaiting),
      departures: departures,
    );
  }

  /// One extra waiting slot per attempt, while playing or after a jam.
  static Board continueWithSlot(Level l, Board b) {
    if (b.phase(l) == GamePhase.won || b.continued) {
      return b;
    }
    return Board(
      taken: b.taken,
      waiting: b.waiting,
      busIndex: b.busIndex,
      boarded: b.boarded,
      moves: b.moves,
      slots: b.slots + 1,
      continued: true,
    );
  }

  /// Returns a genuine winning route of lane taps from the current state, or
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
      // Prefer the bus colour, then colours whose bus comes soonest.
      int soon(int lane) {
        final color = b.front(level, lane)!;
        for (int k = b.busIndex; k < level.buses.length; k++) {
          if (level.buses[k].index == color) return k - b.busIndex;
        }
        return 99;
      }

      final choices = [
        for (int i = 0; i < b.taken.length; i++)
          if (b.open(level, i)) i,
      ]..sort((a, c) => soon(a).compareTo(soon(c)));
      for (final lane in choices) {
        final result = tap(level, b, lane);
        final tail = visit(result.board);
        if (tail != null) return [lane, ...tail];
      }
      return null;
    }

    return visit(start);
  }

  /// Sum of waiting passengers after each move along [route].
  static int waitingCost(Level level, List<int> route) {
    var board = Board.initial(level);
    var cost = 0;
    for (final lane in route) {
      final result = tap(level, board, lane);
      if (!result.accepted) throw StateError('Blocked route');
      board = result.board;
      cost += board.waiting.length;
    }
    return cost;
  }
}
