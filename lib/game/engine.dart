import 'model.dart';

/// Pure deterministic rules. Only the front bus can enter an empty parking slot.
class GameEngine {
  /// Exact minimum settled parking occupancy over a winning path. The graph
  /// is acyclic: every release removes a bus from its lane. Parked bus order
  /// remains in the key because equal-colour buses can have different sizes.
  static RouteAnalysis analyze(Level level, {int maxStates = 100000}) {
    final memo = <String, ({List<int> route, int cost})?>{};
    var decisions = 0, losingChoices = 0;
    ({List<int> route, int cost})? visit(Board board) {
      if (board.phase(level) == GamePhase.won) return (route: <int>[], cost: 0);
      if (board.phase(level) == GamePhase.failed) return null;
      final key = board.searchKey;
      if (memo.containsKey(key)) return memo[key];
      if (memo.length >= maxStates) throw StateError('Puzzle analysis budget exhausted');
      memo[key] = null;
      ({List<int> route, int cost})? best;
      var safe = 0, unsafe = 0;
      for (int lane = 0; lane < board.lanes.length; lane++) {
        final move = release(level, board, lane);
        if (!move.accepted) continue;
        final tail = visit(move.board);
        if (tail == null) {
          unsafe++;
          continue;
        }
        safe++;
        final cost = move.board.parked.length + tail.cost;
        if (best == null || cost < best.cost) best = (route: [lane, ...tail.route], cost: cost);
      }
      if (safe > 0 && unsafe > 0) decisions++;
      losingChoices += unsafe;
      memo[key] = best;
      return best;
    }
    final best = visit(Board.initial(level));
    if (best == null) throw StateError('Unsolvable puzzle');
    return RouteAnalysis(List.unmodifiable(best.route), best.cost, memo.length, decisions, losingChoices);
  }
  static MoveResult release(Level level, Board board, int lane) {
    if (board.phase(level) != GamePhase.playing ||
        lane < 0 ||
        lane >= board.lanes.length ||
        board.lanes[lane].isEmpty ||
        board.parked.length >= board.slots) {
      return MoveResult(board);
    }
    final lanes = board.lanes.map((l) => l.toList()).toList();
    final parked = [...board.parked, lanes[lane].removeAt(0)];
    var cursor = board.cursor;
    final boarding = <Boarding>[];
    final departed = <Bus>[];
    while (cursor < level.passengers.length) {
      final index = parked.indexWhere(
        (b) => b.color == level.passengers[cursor],
      );
      if (index < 0) {
        break;
      }
      final bus = parked[index].board();
      boarding.add(Boarding(cursor, bus.id, bus.color));
      cursor++;
      if (bus.boarded == bus.capacity) {
        departed.add(bus);
        parked.removeAt(index);
      } else {
        parked[index] = bus;
      }
    }
    final next = Board(
      lanes: lanes,
      parked: parked,
      cursor: cursor,
      departed: board.departed + departed.length,
      moves: board.moves + 1,
      slots: board.slots,
      continued: board.continued,
    );
    return MoveResult(
      next,
      accepted: true,
      boarding: List.unmodifiable(boarding),
      departures: List.unmodifiable(departed),
    );
  }

  static Board continueWithSlot(Level l, Board b) {
    if (b.phase(l) != GamePhase.failed || b.continued) {
      return b;
    }
    return Board(
      lanes: b.lanes,
      parked: b.parked,
      cursor: b.cursor,
      departed: b.departed,
      moves: b.moves,
      slots: b.slots + 1,
      continued: true,
    );
  }

  /// Returns a genuine winning route from the current state, or null for a dead end.
  /// Budget exhaustion never produces a fabricated hint.
  static List<int>? solve(Level level, Board start, {int maxStates = 60000}) {
    final visited = <String>{};
    List<int>? visit(Board b) {
      if (b.phase(level) == GamePhase.won) {
        return [];
      }
      if (b.phase(level) == GamePhase.failed ||
          visited.length >= maxStates ||
          !visited.add(b.searchKey)) {
        return null;
      }
      final choices = List.generate(b.lanes.length, (i) => i);
      choices.sort((a, c) {
        final wanted = level.passengers[b.cursor];
        final am = b.lanes[a].isNotEmpty && b.lanes[a].first.color == wanted;
        final cm = b.lanes[c].isNotEmpty && b.lanes[c].first.color == wanted;
        return (cm ? 1 : 0) - (am ? 1 : 0);
      });
      for (final lane in choices) {
        final result = release(level, b, lane);
        if (!result.accepted) {
          continue;
        }
        final tail = visit(result.board);
        if (tail != null) {
          return [lane, ...tail];
        }
      }
      return null;
    }

    return visit(start);
  }
}

class RouteAnalysis {
  const RouteAnalysis(this.route, this.parkingCost, this.states, this.decisions, this.losingChoices);
  final List<int> route;
  final int parkingCost, states, decisions, losingChoices;
}
