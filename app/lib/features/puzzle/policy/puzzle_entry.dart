/// What a player has put into a board so far, and whether it is finished.
///
/// **PURE** — a value in, a new value out. No widget, no store, no clock, so
/// the whole of "what happens when you type a 3" is testable without pumping a
/// screen.
///
/// **It does not know which cells are wrong** (design D4), and that is the
/// point. The board reports solved or not solved and nothing between. A grid
/// that reddened a cell the moment it disagreed with the solution would let a
/// player brute-force it one digit at a time — and the solution is on the
/// device only so that grading works with no server, not so the board can hint
/// with it.
library;

import '../../../content/model/puzzle.dart';

/// A board mid-solve.
class PuzzleEntry {
  const PuzzleEntry({required this.board, this.selected, this.filled = const <Cell, int>{}});

  /// A fresh attempt at [board], with nothing selected and nothing entered.
  factory PuzzleEntry.of(PuzzleBoard board) => PuzzleEntry(board: board);

  final PuzzleBoard board;

  /// The cell a digit would land in, or null when the player has chosen none.
  final Cell? selected;

  /// What the player has entered. Only open cells ever appear here.
  final Map<Cell, int> filled;

  /// Selects [cell], or nothing when it is not the player's to fill.
  ///
  /// A given is part of the question and a blocked cell holds nothing, so
  /// tapping either leaves the selection where it was rather than moving it
  /// somewhere a digit cannot go.
  PuzzleEntry select(Cell cell) {
    if (board.blocked.contains(cell) || board.given.contains(cell)) {
      return this;
    }
    if (cell.row < 0 || cell.col < 0 || cell.row >= board.size || cell.col >= board.size) {
      return this;
    }
    return PuzzleEntry(board: board, selected: cell, filled: filled);
  }

  /// Puts [value] in the selected cell, replacing whatever was there.
  ///
  /// Ignored when nothing is selected — a digit landing somewhere the player is
  /// not looking is worse than a digit doing nothing — and when the value is
  /// outside the board's domain, since no such number can appear in a solution.
  PuzzleEntry type(int value) {
    final Cell? cell = selected;
    if (cell == null || value < 1 || value > board.size) {
      return this;
    }
    return PuzzleEntry(
      board: board,
      selected: cell,
      filled: <Cell, int>{...filled, cell: value},
    );
  }

  /// Empties the selected cell. A no-op when nothing is selected or the cell is
  /// already empty.
  PuzzleEntry clear() {
    final Cell? cell = selected;
    if (cell == null) {
      return this;
    }
    return PuzzleEntry(
      board: board,
      selected: cell,
      filled: <Cell, int>{...filled}..remove(cell),
    );
  }

  /// What is in [cell] — entered, given, or nothing.
  int? valueAt(Cell cell) {
    if (board.given.contains(cell)) {
      return board.valueAt(cell);
    }
    return filled[cell];
  }

  /// Whether every open cell has been filled, right or wrong.
  bool get isFull => board.openCells.every(filled.containsKey);

  /// Whether every open cell matches the solution.
  ///
  /// Full and correct are different questions and only this one is answered
  /// out loud.
  bool get isSolved =>
      board.openCells.every((Cell cell) => filled[cell] == board.valueAt(cell));
}
