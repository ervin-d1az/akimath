/// Finding a word in a grid of letters.
///
/// **PURE**, and shared between the reader and the player (design D2). The
/// reader asks *is this word anywhere in this grid*; a claim asks *do these
/// cells spell a word*. Both are the same eight-direction reading, and a second
/// implementation would be free to disagree about diagonals — a disagreement a
/// player would experience as a correct answer refused.
///
/// It lives beside the model rather than in the feature because
/// `puzzle_reader.dart` needs it: a reader importing a screen's policy is a
/// model depending on a feature, and the arrow points the other way.
library;

import 'puzzle.dart';

/// The eight ways a word may run: along, back, down, up, and both diagonals
/// each way.
///
/// **Eight, because the frozen validator uses eight.** A reader searching only
/// the four an author happened to use would accept a pack whose words a player
/// cannot claim.
const List<(int, int)> wordDirections = <(int, int)>[
  (0, 1),
  (0, -1),
  (1, 0),
  (-1, 0),
  (1, 1),
  (1, -1),
  (-1, 1),
  (-1, -1),
];

/// Whether [word] reads from [start] in [step] without leaving the grid.
bool _readsAs(
  List<String> grid,
  String word,
  Cell start,
  (int, int) step,
) {
  for (int offset = 0; offset < word.length; offset++) {
    final int row = start.row + step.$1 * offset;
    final int col = start.col + step.$2 * offset;
    if (row < 0 || row >= grid.length) {
      return false;
    }
    final String line = grid[row];
    // Off the end is a miss, never a wrap and never a shorter prefix.
    if (col < 0 || col >= line.length) {
      return false;
    }
    if (line[col] != word[offset]) {
      return false;
    }
  }
  return true;
}

/// Whether [word] appears anywhere in [grid], in any direction.
bool containsWord(List<String> grid, String word) {
  if (word.isEmpty) {
    return false;
  }
  for (int row = 0; row < grid.length; row++) {
    for (int col = 0; col < grid[row].length; col++) {
      for (final (int, int) step in wordDirections) {
        if (_readsAs(grid, word, Cell(row: row, col: col), step)) {
          return true;
        }
      }
    }
  }
  return false;
}

/// The letters a straight line of cells spells, or null when it is not a line.
///
/// **A word here is a line by definition**, so a trace that bends claims
/// nothing rather than claiming whatever letters it happened to cross.
String? lineReads(List<String> grid, List<Cell> trace) {
  if (trace.length < 2) {
    return null;
  }
  final int stepRow = trace[1].row - trace[0].row;
  final int stepCol = trace[1].col - trace[0].col;
  // Neighbours only: a "line" of distant cells is a selection with holes.
  if (stepRow.abs() > 1 || stepCol.abs() > 1 || (stepRow == 0 && stepCol == 0)) {
    return null;
  }
  for (int i = 1; i < trace.length; i++) {
    if (trace[i].row - trace[i - 1].row != stepRow ||
        trace[i].col - trace[i - 1].col != stepCol) {
      return null;
    }
  }

  final StringBuffer letters = StringBuffer();
  for (final Cell cell in trace) {
    if (cell.row < 0 ||
        cell.row >= grid.length ||
        cell.col < 0 ||
        cell.col >= grid[cell.row].length) {
      return null;
    }
    letters.write(grid[cell.row][cell.col]);
  }
  return letters.toString();
}

