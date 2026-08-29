import '../../../content/model/puzzle.dart';

/// What a board format shows besides its cells.
///
/// **The one place a board format is named while deciding what to draw.**
/// `PuzzleScreen` used to build `PuzzleBoardView` from four `switch`
/// expressions, each ending in `_ => const <…>[]`, and the view then asked
/// whether two of those lists were empty to decide whether to make room for a
/// margin. Format identity was reconstructed downstream from the emptiness of
/// data — the shape that let `pack.puzzles.first` hide four formats behind an
/// `is! KenKenPuzzle` guard, inverted: not a type test standing in for a
/// decision, but data emptiness standing in for one, which is harder to grep
/// for. A sixth format compiled, opened from the home, passed the
/// *5 kinds reachable* gate and drew a grid with none of its constraints on
/// it. `docs/solid/puzzle.md`, finding 1.
///
/// **There is no empty constructor**, deliberately: a format has to say what
/// it puts on the board, and *nothing* is not one of the answers. What the
/// compiler cannot promise is that a **new kind** of constraint reaches the
/// screen — a sixth format that brought one would get an arm here and a field
/// on this type, and `PuzzleBoardView` could still ignore that field without a
/// diagnostic. So the split is: the compiler owns *no format goes unnamed*,
/// and `board_constraints_test.dart`'s sweep owns *no format shows nothing*.
class BoardConstraints {
  /// A board divided into cages, each asking for a target.
  const BoardConstraints.cages(this.cages)
      : rowTargets = const <int>[],
        columnTargets = const <int>[],
        runs = const <Run>[];

  /// A board whose every line has a total to reach, shown beside it.
  const BoardConstraints.lineTargets({
    required this.rowTargets,
    required this.columnTargets,
  })  : cages = const <Cage>[],
        runs = const <Run>[];

  /// A board clued by the sums of the runs crossing it.
  const BoardConstraints.runs(this.runs)
      : cages = const <Cage>[],
        rowTargets = const <int>[],
        columnTargets = const <int>[];

  /// The cages to outline, each with the target it asks for.
  final List<Cage> cages;

  /// What each row must total, top to bottom.
  final List<int> rowTargets;

  /// What each column must total, left to right.
  final List<int> columnTargets;

  /// The runs whose sums are clued on the board.
  final List<Run> runs;

  /// Whether the board has to leave room beside itself for a line of totals.
  ///
  /// The view asked two lists whether they were empty; asking here keeps the
  /// question where a test can read the answer without pumping a widget, and
  /// keeps the grid the same size on the formats that draw no margin.
  bool get hasLineTargets => rowTargets.isNotEmpty || columnTargets.isNotEmpty;
}

/// What this puzzle puts on its board.
///
/// **Switched over the sealed hierarchy's leaves**, so a sixth format is a
/// compile error here rather than a board drawn with its constraints missing —
/// the same construction `puzzleFormatName` uses one file over.
///
/// KenKen and Killer are named separately rather than matched as their shared
/// `CagedPuzzle` parent, and that is the point of the rule rather than an
/// oversight: a `CagedPuzzle()` arm would absorb a third caged format silently,
/// drawing the half it shares and dropping whatever else it asked for. The
/// screen still takes `CagedPuzzle` — it needs a capability, not a kind — and
/// the naming happens once, here.
BoardConstraints boardConstraints(BoardPuzzle puzzle) => switch (puzzle) {
      KenKenPuzzle(:final List<Cage> cages) => BoardConstraints.cages(cages),
      KillerPuzzle(:final List<Cage> cages) => BoardConstraints.cages(cages),
      MagicSquarePuzzle(
        :final List<int> rowTargets,
        :final List<int> columnTargets,
      ) =>
        BoardConstraints.lineTargets(
          rowTargets: rowTargets,
          columnTargets: columnTargets,
        ),
      KakuroPuzzle(:final List<Run> runs) => BoardConstraints.runs(runs),
    };
