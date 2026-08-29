import '../../../content/model/puzzle.dart';
import '../../../design/puzzle/spec/cage_outline.dart';

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
///
/// **A cage arrives with the outline it is drawn in**, because the second half
/// of the same defect was a cage whose *appearance* went unnamed: both widgets
/// that paint one named `DashSpec.kenKenCage` themselves, so the seven Killer
/// boards in the shipped pack drew KenKen's `6 4` while `CageOutline.killer`
/// described the format correctly and reached no screen. Pairing them on
/// [BoardConstraints.cages] is what makes *a cage without its outline*
/// unconstructible rather than asserted — see [outline].
class BoardConstraints {
  /// A board divided into cages, each asking for a target, drawn in [outline].
  ///
  /// The outline is **not** optional here: this is the only constructor that
  /// admits cages, and it demands the appearance in the same breath.
  const BoardConstraints.cages(this.cages, CageOutline this.outline)
      : rowTargets = const <int>[],
        columnTargets = const <int>[],
        runs = const <Run>[];

  /// A board whose every line has a total to reach, shown beside it.
  const BoardConstraints.lineTargets({
    required this.rowTargets,
    required this.columnTargets,
  })  : cages = const <Cage>[],
        runs = const <Run>[],
        outline = null;

  /// A board clued by the sums of the runs crossing it.
  const BoardConstraints.runs(this.runs)
      : cages = const <Cage>[],
        rowTargets = const <int>[],
        columnTargets = const <int>[],
        outline = null;

  /// The cages to outline, each with the target it asks for.
  final List<Cage> cages;

  /// How those cages are drawn, and null for the formats that have none.
  ///
  /// **A constructor shape rather than an `assert`** (TYP-2). The pairing was
  /// written as `assert(cages.isEmpty == (cageOutline == null))` on
  /// `PuzzleBoardView`, which Dart strips in release — so the guarantee held in
  /// every test and in no build a player runs — and which is *also* wrong in
  /// debug: `KillerPuzzle(cages: <Cage>[])` is a state the model permits and
  /// `reference_card_test.dart` already builds, and that assert throws on it.
  /// What the type now promises is exactly what is true: **non-null if and only
  /// if this is the caged constructor**, so cages can never reach the board
  /// without an appearance, and no other constructor can smuggle one in.
  ///
  /// What stays representable is `BoardConstraints.cages(<Cage>[], kenKen)` — a
  /// caged format carrying no cages — and it draws nothing, which is the same
  /// nothing it drew before. TYP-2's last paragraph is why that is said here
  /// rather than left for a reader to discover.
  final CageOutline? outline;

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
///
/// **Once, including the outline.** The cage fix arrived as a second
/// exhaustive switch over the same sealed type — `cagePlanFor`, producing the
/// cages and their appearance — which is two functions that have to be edited
/// together for a sixth format and no compiler saying so. They are one switch:
/// the two facts a caged format contributes are decided in the same arm.
BoardConstraints boardConstraints(BoardPuzzle puzzle) => switch (puzzle) {
      KenKenPuzzle(:final List<Cage> cages) =>
        BoardConstraints.cages(cages, CageOutline.kenKen),
      KillerPuzzle(:final List<Cage> cages) =>
        BoardConstraints.cages(cages, CageOutline.killer),
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
