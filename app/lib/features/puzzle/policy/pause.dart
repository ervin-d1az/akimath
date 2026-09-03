/// What `Pausa` says about the board underneath it.
///
/// **PURE** — a puzzle and an entry in, four readings out. No clock, and that
/// is the whole shape of this type rather than an omission.
///
/// `CLAUDE.md`'s *nothing watches you while you work* forbids anything reading
/// as a clock on a solving surface, and a paused board is mid-solve: the player
/// has not finished, and telling them how long they have been at it is exactly
/// the pressure the rule exists to keep off. The design agrees — `Pausa` is
/// drawn with a cell count and a format name and no elapsed time, while
/// `Puzzle resuelto`, one screen away, does show `11:24 TIEMPO`. So there is
/// nowhere in this type to put a duration, and a screen cannot print one it was
/// never handed.
library;

import '../../../content/model/puzzle.dart';
import 'puzzle_entry.dart';
import 'reference_card.dart';

/// The four readings a paused board offers.
class PauseSummary {
  const PauseSummary({
    required this.filled,
    required this.total,
    required this.formatName,
    required this.sizeLabel,
  });

  /// How many of the player's own cells carry a value.
  final int filled;

  /// How many cells are the player's to fill: everything neither blocked nor
  /// given. A given is part of the question, so counting it would report work
  /// the player has not done.
  final int total;

  /// `KENKEN`, `KAKURO` — the same name the board's header carries.
  final String formatName;

  /// `6 × 6`, spelled the way the design draws it.
  final String sizeLabel;
}

/// What to show over a board that has been paused.
PauseSummary pauseSummary(BoardPuzzle puzzle, PuzzleEntry entry) {
  final List<Cell> open = puzzle.board.openCells.toList();
  return PauseSummary(
    filled: open.where(entry.filled.containsKey).length,
    total: open.length,
    formatName: puzzleFormatName(puzzle),
    sizeLabel: '${puzzle.board.size} × ${puzzle.board.size}',
  );
}
