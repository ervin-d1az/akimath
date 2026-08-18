import 'dart:ui' show Offset, Size;

import 'package:akimath_app/design/puzzle/spec/board_geometry.dart' show GridCell;
import 'package:akimath_app/design/puzzle/spec/letter_grid_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 4-wide, 2-tall grid in a 400×200 box: cells are 100×100.
const Size _box = Size(400, 200);
const int _rows = 2;
const int _columns = 4;

GridCell? _at(double x, double y) => letterAt(
      Offset(x, y),
      box: _box,
      rows: _rows,
      columns: _columns,
    );

void main() {
  group('a point lands in the cell that contains it', () {
    test('the first cell', () {
      expect(_at(0, 0), const GridCell(0, 0));
      expect(_at(99, 99), const GridCell(0, 0));
    });

    test('the last cell', () {
      expect(_at(399, 199), const GridCell(1, 3));
    });

    test('rows and columns are not transposed', () {
      // The one mistake this can make that a square grid would hide: the box is
      // 4 wide and 2 tall, so a transposed reading of (250, 50) would be
      // row 2 — off the end — instead of column 2.
      expect(_at(250, 50), const GridCell(0, 2));
      expect(_at(50, 150), const GridCell(1, 0));
    });

    test('a boundary belongs to the cell it starts', () {
      // Exactly on the seam. Without a rule the two neighbours both claim it
      // and which one wins depends on rounding.
      expect(_at(100, 0), const GridCell(0, 1));
      expect(_at(0, 100), const GridCell(1, 0));
    });
  });

  group('a point outside the grid is nobody\'s', () {
    test('past either edge', () {
      // A drag that leaves the grid must not clamp to the nearest cell: that
      // would let a player trace a word by sweeping off the side of the phone.
      expect(_at(400, 100), isNull);
      expect(_at(100, 200), isNull);
      expect(_at(-1, 50), isNull);
      expect(_at(50, -1), isNull);
    });
  });

  group('a grid with no area has no cells', () {
    test('zero rows or columns', () {
      // Division by zero otherwise, and the reader forbids both — so this is
      // the caller's guard, not a case the format can produce.
      expect(
        letterAt(Offset.zero, box: _box, rows: 0, columns: _columns),
        isNull,
      );
      expect(
        letterAt(Offset.zero, box: _box, rows: _rows, columns: 0),
        isNull,
      );
    });

    test('a box with no width', () {
      expect(
        letterAt(Offset.zero, box: Size.zero, rows: _rows, columns: _columns),
        isNull,
      );
    });
  });
}
