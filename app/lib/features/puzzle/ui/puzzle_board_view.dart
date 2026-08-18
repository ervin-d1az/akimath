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
  });

  final PuzzleEntry entry;

  /// The cages to outline, each with the target it asks for.
  final List<Cage> cages;

  final ValueChanged<Cell> onTapCell;

  @override
  Widget build(BuildContext context) {
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
    required this.onTap,
  });

  final Cell cell;
  final PuzzleEntry entry;
  final CageEdges? edges;
  final String? target;
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
