/// Where a puzzle board's cells and cage outlines go.
///
/// **PURE geometry.** Counts in, rectangles and edges out — no `Canvas`, no
/// widget, no size beyond the box it is handed. `dart:ui`'s `Rect` and `Offset`
/// are value types with no rendering attached, the same licence
/// `figurate_layout.dart` and `fraction_metrics.dart` take.
///
/// It lives here rather than in the widget because `no_geometry_literal_test`
/// scans `features/` for `Offset(` — and a grid is nothing but offsets. The
/// widget consumes what this computes and constructs none of its own, which is
/// the split that keeps the arithmetic testable without pumping a screen.
library;

import 'dart:ui' show Offset, Rect;

/// A cell's position on the board. Mirrors `content/model/puzzle.dart`'s `Cell`
/// without depending on it: geometry knows about rows and columns, not about
/// packs.
class GridCell {
  const GridCell(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

/// Which sides of a cell lie on its cage's boundary.
///
/// **Derived from set membership, never authored** (design D3). A cage is a
/// list of cells; its outline is the edges those cells do not share with each
/// other. Carrying the outline in the payload would be a second description of
/// the same fact, free to disagree with the first.
class CageEdges {
  const CageEdges({
    required this.cell,
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  final GridCell cell;
  final bool top;
  final bool right;
  final bool bottom;
  final bool left;

  /// Whether any side of this cell is on the boundary. A cell fully surrounded
  /// by its own cage draws nothing.
  bool get hasAny => top || right || bottom || left;
}

/// The square a cell occupies inside [box], for a board [size] wide.
///
/// Cells are equal and gapless: the border between two of them is one line, not
/// two abutting ones, which is what keeps a grid from looking heavier down the
/// middle than at the edges.
Rect cellRect(GridCell cell, {required int size, required Rect box}) {
  if (size < 1) {
    throw RangeError('a board needs at least one cell, got $size');
  }
  if (cell.row < 0 || cell.col < 0 || cell.row >= size || cell.col >= size) {
    throw RangeError('$cell is outside a $size square');
  }
  final double side = box.shortestSide / size;
  // Anchored to the box's top-left and squared off the shorter axis, so a board
  // in a non-square box stays a square rather than stretching into it.
  return Rect.fromLTWH(
    box.left + cell.col * side,
    box.top + cell.row * side,
    side,
    side,
  );
}

/// The outline of a cage, one entry per cell that has at least one edge on it.
///
/// A neighbour inside the same cage means no edge; anything else — another
/// cage, or the board's rim — means an edge.
List<CageEdges> cageOutline(Set<GridCell> cells) {
  final List<CageEdges> edges = <CageEdges>[];
  for (final GridCell cell in cells) {
    final CageEdges found = CageEdges(
      cell: cell,
      top: !cells.contains(GridCell(cell.row - 1, cell.col)),
      right: !cells.contains(GridCell(cell.row, cell.col + 1)),
      bottom: !cells.contains(GridCell(cell.row + 1, cell.col)),
      left: !cells.contains(GridCell(cell.row, cell.col - 1)),
    );
    if (found.hasAny) {
      edges.add(found);
    }
  }
  // Reading order, so two runs over the same cage draw the same list — a set's
  // iteration order is not something to rely on for anything a person sees.
  edges.sort((CageEdges a, CageEdges b) => a.cell.row != b.cell.row
      ? a.cell.row - b.cell.row
      : a.cell.col - b.cell.col);
  return edges;
}

/// Which cell carries a cage's target label.
///
/// The topmost, then the leftmost — the corner a reader's eye reaches first,
/// and a rule rather than a choice, so two cages never both claim a cell and no
/// cage's label moves when its cells are listed in another order.
GridCell cageLabelAnchor(Set<GridCell> cells) {
  if (cells.isEmpty) {
    throw ArgumentError('an empty cage has no corner to label');
  }
  return cells.reduce((GridCell best, GridCell cell) {
    if (cell.row != best.row) {
      return cell.row < best.row ? cell : best;
    }
    return cell.col < best.col ? cell : best;
  });
}

/// Where inside a cell its target label sits — the top-left, inset.
Offset labelOrigin(Rect cell, {double inset = 0.08}) =>
    Offset(cell.left + cell.width * inset, cell.top + cell.height * inset);
