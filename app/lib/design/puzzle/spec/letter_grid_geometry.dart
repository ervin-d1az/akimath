/// Which letter a finger is on.
///
/// **PURE geometry.** A point, a box and two counts in; a cell or nothing out.
/// It lives beside `board_geometry.dart` for the same reason: a word search is
/// traced by dragging, and a drag is resolved by arithmetic on offsets that
/// `no_geometry_literal_test` will not let a widget do.
///
/// A numeric board hit-tests per cell, because a tap lands on one widget. A
/// drag does not: once the pointer leaves the cell it went down on, no other
/// cell hears about it. So the whole grid takes one gesture and asks this
/// where the finger is.
library;

import 'dart:ui' show Offset, Size;

import 'board_geometry.dart' show GridCell;

/// The cell at [point], or null when the point is outside the grid.
///
/// **Outside is null, never the nearest cell.** Clamping would let a player
/// trace a word by sweeping off the side of the phone, which is not a line
/// through the grid and must not read as one.
///
/// A point exactly on a seam belongs to the cell it starts — the same rule
/// `Rect.contains` uses, stated here so the two neighbours cannot both claim it.
GridCell? letterAt(
  Offset point, {
  required Size box,
  required int rows,
  required int columns,
}) {
  if (rows <= 0 || columns <= 0 || box.width <= 0 || box.height <= 0) {
    return null;
  }
  if (point.dx < 0 || point.dy < 0 || point.dx >= box.width || point.dy >= box.height) {
    return null;
  }

  final int col = (point.dx * columns / box.width).floor();
  final int row = (point.dy * rows / box.height).floor();
  return GridCell(row, col);
}
