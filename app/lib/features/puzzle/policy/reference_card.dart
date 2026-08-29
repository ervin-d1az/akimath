/// What `3.3 Hoja de referencia` shows, decided without a widget.
///
/// **The words are the pack's and the pictures are ours.** A board whose rules
/// were hard-coded here could not have a second kind — that reasoning has been
/// on `PuzzleScreen` since the sheet was three lines of plain text, and it is
/// why [ReferenceRow] takes its `text` from `Puzzle.referenceSheet` and nothing
/// in this file writes a rule. A diagram is the opposite case: it is drawing,
/// it belongs to the format rather than to the content, and shipping one inside
/// a JSON pack would mean shipping geometry through the offline contract.
///
/// The two are paired **by position**, which is the only thing that can be true
/// of a list this file did not write. The sheet is three lines today in all
/// five formats and the schema admits one to six, so a fourth line is text with
/// nothing beside it rather than a picture about some other rule.
library;

import '../../../content/model/puzzle.dart';
import '../../../design/puzzle/spec/cage_outline.dart';

/// A miniature board drawn beside a rule.
///
/// **One shape, configured, rather than a painter per picture.** Eight
/// drawings that differ only in which cells are dark, which are marked and
/// where the dashed cage sits are eight chances to disagree about what a cell
/// looks like; this is the same argument `PuzzleBoardView` makes about cages.
///
/// Every position is an index into a row-major `size × size` grid, so nothing
/// here is a coordinate and this file stays on the pure side of
/// `no_geometry_literal_test`.
class ReferenceDiagram {
  const ReferenceDiagram({
    required this.size,
    this.labels = const <int, String>{},
    this.shaded = const <int>{},
    this.highlighted = const <int>{},
    this.cage = const <int>{},
    this.cageLabel,
    this.cageOutline,
  });

  /// The side of the grid, in cells.
  final int size;

  /// What a cell prints, by index.
  final Map<int, String> labels;

  /// Cells that take no value — Kakuro's dark squares.
  final Set<int> shaded;

  /// Cells the rule is about: a row, a column, a word.
  final Set<int> highlighted;

  /// The cells inside the dashed outline.
  final Set<int> cage;

  /// What that outline's corner says. Null when there is no cage.
  final String? cageLabel;

  /// The outline those cells are drawn in. Null exactly when there is no cage.
  ///
  /// Held by a sweep over [allReferenceDiagrams] rather than by an assert here,
  /// because a `const` constructor may not call `isEmpty`. That is what the
  /// list is for: a diagram that draws a cage and names no outline would draw
  /// nothing at all, and one that named the wrong one would teach a format the
  /// player is not looking at.
  final CageOutline? cageOutline;
}

/// One line of the sheet and the picture that goes with it.
class ReferenceRow {
  const ReferenceRow({required this.text, this.diagram});

  /// From the pack, verbatim.
  final String text;

  /// Null when the pack carried more lines than this format draws pictures for.
  final ReferenceDiagram? diagram;
}

/// A grid with a few numbers in it: *fill every cell*.
const ReferenceDiagram _fillEveryCell = ReferenceDiagram(
  size: 3,
  labels: <int, String>{0: '1', 4: '3', 8: '2'},
);

/// A dashed cage carrying a result and its sign.
const ReferenceDiagram _cageWithSign = ReferenceDiagram(
  size: 3,
  cage: <int>{0, 1},
  cageLabel: '6×',
  cageOutline: CageOutline.kenKen,
);

/// A dashed cage carrying a plain sum, which is how Killer says *add*.
const ReferenceDiagram _cageWithSum = ReferenceDiagram(
  size: 3,
  cage: <int>{0, 1},
  cageLabel: '5',
  cageOutline: CageOutline.killer,
);

/// A marked row crossing a marked column: *nothing repeats in a line*.
const ReferenceDiagram _lineWithoutRepeats = ReferenceDiagram(
  size: 3,
  highlighted: <int>{0, 1, 2, 5, 8},
  labels: <int, String>{0: '1', 1: '2', 2: '3'},
);

/// The targets down the edge of a magic square.
const ReferenceDiagram _edgeTargets = ReferenceDiagram(
  size: 3,
  shaded: <int>{2, 5, 8},
  labels: <int, String>{2: '15', 5: '15', 8: '15'},
);

/// A dark clue square and the white run it starts.
const ReferenceDiagram _clueAndRun = ReferenceDiagram(
  size: 3,
  shaded: <int>{0, 3, 6, 4, 7},
  highlighted: <int>{1, 2},
  labels: <int, String>{0: '9'},
);

/// A rectangle of letters.
const ReferenceDiagram _letterGrid = ReferenceDiagram(
  size: 3,
  labels: <int, String>{
    0: 'S',
    1: 'U',
    2: 'M',
    3: 'A',
    4: 'R',
    5: 'E',
    6: 'C',
    7: 'O',
    8: 'S',
  },
);

/// One word traced straight through the letters.
const ReferenceDiagram _tracedWord = ReferenceDiagram(
  size: 3,
  highlighted: <int>{0, 1, 2},
  labels: <int, String>{0: 'S', 1: 'U', 2: 'M', 4: 'R', 8: 'S'},
);

/// A row, a column and a diagonal: *straight, in any of eight directions*.
const ReferenceDiagram _straightLines = ReferenceDiagram(
  size: 3,
  highlighted: <int>{0, 4, 8, 6, 7},
);

/// Every diagram this file can draw.
///
/// A list rather than a derived set, so a test can sweep them without knowing
/// which format uses which — and so one that no format reaches is still held to
/// the same invariants (PROC-10).
const List<ReferenceDiagram> allReferenceDiagrams = <ReferenceDiagram>[
  _fillEveryCell,
  _cageWithSign,
  _cageWithSum,
  _lineWithoutRepeats,
  _edgeTargets,
  _clueAndRun,
  _letterGrid,
  _tracedWord,
  _straightLines,
];

/// The pictures a format draws, in the order its sheet states its rules:
/// objective, then vocabulary, then constraints.
List<ReferenceDiagram> _diagramsFor(Puzzle puzzle) => switch (puzzle) {
      KenKenPuzzle() => <ReferenceDiagram>[
          _fillEveryCell,
          _cageWithSign,
          _lineWithoutRepeats,
        ],
      KillerPuzzle() => <ReferenceDiagram>[
          _fillEveryCell,
          _cageWithSum,
          _lineWithoutRepeats,
        ],
      MagicSquarePuzzle() => <ReferenceDiagram>[
          _fillEveryCell,
          _edgeTargets,
          _lineWithoutRepeats,
        ],
      KakuroPuzzle() => <ReferenceDiagram>[
          _fillEveryCell,
          _clueAndRun,
          _lineWithoutRepeats,
        ],
      WordSearchPuzzle() => <ReferenceDiagram>[
          _letterGrid,
          _tracedWord,
          _straightLines,
        ],
    };

/// The sheet the pack carried, each line beside its picture.
List<ReferenceRow> referenceRows(Puzzle puzzle) {
  final List<ReferenceDiagram> diagrams = _diagramsFor(puzzle);
  return <ReferenceRow>[
    for (int line = 0; line < puzzle.referenceSheet.length; line++)
      ReferenceRow(
        text: puzzle.referenceSheet[line],
        diagram: line < diagrams.length ? diagrams[line] : null,
      ),
  ];
}

/// The kind, named for the player.
///
/// **Switched over the sealed type**, so a sixth format is a compile error
/// here rather than a board labelled KENKEN. It lives in the policy because
/// three surfaces need it — the board's header, the sopa's header and the card
/// above them both — and the same name written three times is two that can go
/// stale.
String puzzleFormatName(Puzzle puzzle) => switch (puzzle) {
      KenKenPuzzle() => 'KENKEN',
      KillerPuzzle() => 'SUMAS',
      MagicSquarePuzzle() => 'CUADRO MÁGICO',
      KakuroPuzzle() => 'KAKURO',
      WordSearchPuzzle() => 'SOPA DE LETRAS',
    };

/// What the card is headed, following the design's *KENKEN EN CORTO*.
String referenceCardTitle(Puzzle puzzle) => '${puzzleFormatName(puzzle)} EN CORTO';
