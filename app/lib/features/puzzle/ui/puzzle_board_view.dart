import 'package:flutter/widgets.dart';

import '../../../content/model/puzzle.dart';
import '../../../design/puzzle/spec/board_geometry.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/spec/puzzle_cell_visual.dart';
import '../policy/puzzle_entry.dart';

/// The grid: cells, cage outlines and the targets they carry.
///
/// **It constructs no geometry.** Cell rectangles, cage borders and label
/// anchors all come from `board_geometry.dart` — `no_geometry_literal_test`
/// scans this directory for `Offset(`, and a grid is nothing but offsets. What
/// is here is the reading of those numbers into widgets.
///
/// **It never draws a value the player has not entered.** The solution rides
/// along on the device because grading has to work with no server; a cell that
/// showed what it was hiding would give the board away, so
/// `puzzle_board_test.dart` sweeps for exactly that.
class PuzzleBoardView extends StatelessWidget {
  const PuzzleBoardView({
    super.key,
    required this.entry,
    required this.cages,
    required this.onTapCell,
    this.rowTargets = const <int>[],
    this.columnTargets = const <int>[],
    this.runs = const <Run>[],
  });

  final PuzzleEntry entry;

  /// The cages to outline, each with the target it asks for.
  final List<Cage> cages;

  final ValueChanged<Cell> onTapCell;

  /// What each line must total, for the formats that ask. Empty for caged
  /// boards, which draw no margin at all — so a magic square and a KenKen show
  /// the same grid at the same size, and only one has labels beside it.
  final List<int> rowTargets;
  final List<int> columnTargets;

  /// The runs whose sums are clued on the board. Empty for every format but
  /// Kakuro.
  final List<Run> runs;

  @override
  Widget build(BuildContext context) {
    if (rowTargets.isEmpty && columnTargets.isEmpty) {
      return _grid();
    }
    // The margin is space *around* an unchanged square: `cellRect` is untouched
    // and the grid keeps the size it would have had.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // **`IntrinsicHeight`**, so the row-target column has a height to divide.
        // Without it the margin's `Expanded`s are handed unbounded height — the
        // grid's height comes from its own aspect ratio, which the row does not
        // know until it has laid the grid out.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _grid()),
              _margin(rowTargets, vertical: true),
            ],
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(child: _margin(columnTargets, vertical: false)),
            const SizedBox(width: _marginExtent),
          ],
        ),
      ],
    );
  }

  /// How much room a line of targets takes.
  static const double _marginExtent = 28;

  /// The targets down the right or along the bottom.
  Widget _margin(List<int> targets, {required bool vertical}) {
    final List<Widget> labels = <Widget>[
      for (final int target in targets)
        Expanded(
          child: Center(
            child: Text('$target', style: BrandText.eyebrow(size: 11)),
          ),
        ),
    ];
    return SizedBox(
      width: vertical ? _marginExtent : null,
      height: vertical ? null : _marginExtent,
      child: vertical
          ? Column(children: labels)
          : Row(children: labels),
    );
  }

  Widget _grid() {
    // Square, and sized by the narrower axis of whatever it is given — the same
    // rule `cellRect` follows, so the two cannot disagree about how big a cell
    // is.
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double side = constraints.biggest.shortestSide;
          final Rect box = Rect.fromLTWH(0, 0, side, side);
          final Map<Cell, Cage> cageOf = <Cell, Cage>{
            for (final Cage cage in cages)
              for (final Cell cell in cage.cells) cell: cage,
          };

          return SizedBox(
            width: side,
            height: side,
            child: Stack(
              children: <Widget>[
                for (int row = 0; row < entry.board.size; row++)
                  for (int col = 0; col < entry.board.size; col++)
                    _positioned(box, row, col, cageOf),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The clues a cell begins, if any.
  ///
  /// **Anchored to the run's own first cell** rather than a preceding blocked
  /// cell (design D2). Newspaper Kakuro splits the two sums into the black
  /// square before a run; the frozen format does not promise one exists — the
  /// golden fixture has a run starting at column 0 with nothing to its left.
  ///
  /// A cell may begin both an across and a down run, and both are shown: one
  /// that hid the other would hide a constraint the player needs.
  ({String? across, String? down}) _cluesAt(Cell cell) {
    String? across;
    String? down;
    for (final Run run in runs) {
      if (run.cells.first != cell) {
        continue;
      }
      if (run.isAcross) {
        across = '${run.sum}';
      } else {
        down = '${run.sum}';
      }
    }
    return (across: across, down: down);
  }

  Widget _positioned(Rect box, int row, int col, Map<Cell, Cage> cageOf) {
    final Cell cell = Cell(row: row, col: col);
    final Rect rect =
        cellRect(GridCell(row, col), size: entry.board.size, box: box);
    final Cage? cage = cageOf[cell];

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: _Cell(
        cell: cell,
        entry: entry,
        edges: cage == null ? null : _edgesFor(cage, cell),
        // Only the cage's anchor carries the target, so a five-cell cage shows
        // its sum once rather than five times.
        target: cage != null && _isAnchor(cage, cell) ? _label(cage) : null,
        clues: _cluesAt(cell),
        onTap: () => onTapCell(cell),
      ),
    );
  }

  /// What a cage's corner says.
  ///
  /// The target always; the operation only when the format named one and there
  /// is more than one cell to combine. A Killer cage asks for a sum and says so
  /// by saying nothing, and `3+` on a single cell is not a sum in any format.
  String _label(Cage cage) {
    final String? operation = cage.operation;
    if (operation == null || cage.cells.length == 1) {
      return '${cage.target}';
    }
    return '${cage.target}$operation';
  }

  CageEdges? _edgesFor(Cage cage, Cell cell) {
    final Set<GridCell> cells = <GridCell>{
      for (final Cell c in cage.cells) GridCell(c.row, c.col),
    };
    for (final CageEdges edges in cageOutline(cells)) {
      if (edges.cell.row == cell.row && edges.cell.col == cell.col) {
        return edges;
      }
    }
    return null;
  }

  bool _isAnchor(Cage cage, Cell cell) {
    final GridCell anchor = cageLabelAnchor(<GridCell>{
      for (final Cell c in cage.cells) GridCell(c.row, c.col),
    });
    return anchor.row == cell.row && anchor.col == cell.col;
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.cell,
    required this.entry,
    required this.edges,
    required this.target,
    required this.clues,
    required this.onTap,
  });

  final Cell cell;
  final PuzzleEntry entry;
  final CageEdges? edges;
  final String? target;

  /// The run sums this cell begins, along and down.
  final ({String? across, String? down}) clues;

  final VoidCallback onTap;

  PuzzleCellKind get _kind {
    if (entry.board.blocked.contains(cell)) return PuzzleCellKind.blocked;
    if (entry.board.given.contains(cell)) return PuzzleCellKind.given;
    return PuzzleCellKind.open;
  }

  @override
  Widget build(BuildContext context) {
    final PuzzleCellVisual visual = resolvePuzzleCell(_kind);
    final bool selected = entry.selected == cell;
    final int? value = entry.valueAt(cell);
    final CageEdges? outline = edges;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: visual.background,
          // The thin grid, drawn on every cell. The cage's heavier border goes
          // over it below.
          border: Border.all(
            color: BrandColors.muted,
            width: BrandShape.borderWidthField,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: outline == null
                ? null
                : Border(
                    top: _side(outline.top),
                    right: _side(outline.right),
                    bottom: _side(outline.bottom),
                    left: _side(outline.left),
                  ),
          ),
          child: Stack(
            children: <Widget>[
              if (target != null)
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(target!, style: BrandText.eyebrow(size: 10)),
                ),
              // Across at the top, down at the bottom-left — the directions
              // they read in, so the pairing needs no legend.
              if (clues.across != null)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text('${clues.across}→',
                        style: BrandText.eyebrow(size: 9)),
                  ),
                ),
              if (clues.down != null)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text('${clues.down}↓',
                        style: BrandText.eyebrow(size: 9)),
                  ),
                ),
              if (value != null)
                Center(
                  child: Text('$value', style: BrandText.numeral(22)),
                ),
              // **Selection is a ring, not a wash.** A tinted fill would be a
              // hue difference and nothing else; a border survives with the
              // hue gone (BRD-1).
              if (selected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: BrandColors.ink,
                      width: BrandShape.borderWidth,
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  BorderSide _side(bool on) => on
      ? const BorderSide(color: BrandColors.ink, width: BrandShape.borderWidth)
      : BorderSide.none;
}
