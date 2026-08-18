/// A puzzle, as pure data.
///
/// The five formats `packages/contract` froze sit on one substrate: a square
/// board with blocked cells, cells the puzzle supplies, and the solution it is
/// graded against. Only word search departs from it, which is why it is last.
library;

/// A position on the board. Row and column, both from zero.
class Cell {
  const Cell({required this.row, required this.col});

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

/// The square four of the five formats share.
///
/// **The solution travels with the board**, for the reason every offline
/// verdict needs: grading happens on the device with no server. What that costs
/// is a rule the renderer has to keep — an open cell must never draw the value
/// it is hiding — and that is asserted rather than assumed.
class PuzzleBoard {
  const PuzzleBoard({
    required this.size,
    required this.blocked,
    required this.given,
    required this.solution,
  });

  /// 3 to 6, matching the frozen schema.
  final int size;

  /// Cells that take no value at all.
  final Set<Cell> blocked;

  /// Cells the puzzle supplies, already filled. Part of the question.
  final Set<Cell> given;

  /// Row-major, `size` by `size`. Zero is an empty cell.
  final List<List<int>> solution;

  /// The cells a player is expected to fill: everything neither blocked nor
  /// given.
  Iterable<Cell> get openCells sync* {
    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        final Cell cell = Cell(row: row, col: col);
        if (!blocked.contains(cell) && !given.contains(cell)) {
          yield cell;
        }
      }
    }
  }

  int valueAt(Cell cell) => solution[cell.row][cell.col];
}

/// What a cage asks: its cells reaching a target, sometimes by a named
/// operation.
///
/// **`operation` is optional because Killer's cages carry none** — they ask for
/// a sum and say so by saying nothing. Two cage types would have meant two
/// renderers, two outline computations and two label rules, all to model an
/// absence (design D1).
///
/// The model is permissive and the readers are strict: KenKen's requires an
/// operation and Killer's refuses one. That is the right way round — the model
/// describes what can be drawn, the frozen schemas say what may arrive.
class Cage {
  const Cage({
    required this.cells,
    required this.target,
    this.operation,
  });

  final List<Cell> cells;

  /// One of `+`, `-`, `×`, `÷`, or null when the format names none.
  final String? operation;

  final int target;
}

/// A puzzle the app can draw.
///
/// **Sealed**, for the reason `Stimulus` is: the second kind is a compile error
/// at every site that has to draw one, rather than a screen that silently shows
/// nothing.
sealed class Puzzle {
  const Puzzle({required this.tutorialSteps, required this.referenceSheet});

  /// Shown before the first board of this kind. es-MX, from the pack.
  final List<String> tutorialSteps;

  /// The rules, available while playing. es-MX, from the pack.
  final List<String> referenceSheet;

  PuzzleBoard get board;
}

/// A puzzle whose board is divided into cages.
///
/// KenKen and Killer both are, and the screen takes this rather than either —
/// what it needs is a board and some cages, and naming a concrete kind would
/// make every new caged format a change to the screen.
sealed class CagedPuzzle extends Puzzle {
  const CagedPuzzle({required super.tutorialSteps, required super.referenceSheet});

  List<Cage> get cages;
}

final class KenKenPuzzle extends CagedPuzzle {
  const KenKenPuzzle({
    required this.board,
    required this.cages,
    required super.tutorialSteps,
    required super.referenceSheet,
  });

  @override
  final PuzzleBoard board;

  @override
  final List<Cage> cages;
}

/// Cages that ask for a sum, with no operation named.
final class KillerPuzzle extends CagedPuzzle {
  const KillerPuzzle({
    required this.board,
    required this.cages,
    required super.tutorialSteps,
    required super.referenceSheet,
  });

  @override
  final PuzzleBoard board;

  @override
  final List<Cage> cages;
}
