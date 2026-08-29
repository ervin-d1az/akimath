import 'dart:ui' show Rect;

import 'package:akimath_app/design/puzzle/spec/board_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

const Rect _box = Rect.fromLTWH(0, 0, 300, 300);

Set<GridCell> _cage(List<List<int>> pairs) =>
    <GridCell>{for (final List<int> p in pairs) GridCell(p[0], p[1])};

void main() {
  group('cells tile the board', () {
    test('every cell is the same square', () {
      for (final int size in <int>[3, 4, 5, 6]) {
        final double side = 300 / size;
        for (int row = 0; row < size; row++) {
          for (int col = 0; col < size; col++) {
            final Rect r = cellRect(GridCell(row, col), size: size, box: _box);
            expect(r.width, closeTo(side, 1e-9), reason: '$size at $row,$col');
            expect(r.height, closeTo(side, 1e-9));
          }
        }
      }
    });

    test('neighbours share an edge exactly, with no gap and no overlap', () {
      // A gap draws a pale seam; an overlap draws a double-weight line. Both
      // make a grid look heavier down the middle than at its rim.
      final Rect a = cellRect(const GridCell(1, 1), size: 4, box: _box);
      final Rect right = cellRect(const GridCell(1, 2), size: 4, box: _box);
      final Rect below = cellRect(const GridCell(2, 1), size: 4, box: _box);

      expect(a.right, closeTo(right.left, 1e-9));
      expect(a.bottom, closeTo(below.top, 1e-9));
    });

    test('the board fills its box corner to corner', () {
      final Rect first = cellRect(const GridCell(0, 0), size: 5, box: _box);
      final Rect last = cellRect(const GridCell(4, 4), size: 5, box: _box);

      expect(first.left, _box.left);
      expect(first.top, _box.top);
      expect(last.right, closeTo(_box.left + 300, 1e-9));
      expect(last.bottom, closeTo(_box.top + 300, 1e-9));
    });

    test('it stays square in a box that is not, either way round', () {
      // **Both orientations.** A tall box has width as its shorter side, so
      // dividing by the width and dividing by the shorter side agree there —
      // the falsification pass caught that, and the wide case is the one that
      // tells them apart.
      const Rect tall = Rect.fromLTWH(0, 0, 200, 400);
      final Rect inTall = cellRect(const GridCell(0, 0), size: 4, box: tall);
      expect(inTall.width, closeTo(inTall.height, 1e-9));
      expect(inTall.width, closeTo(50, 1e-9));

      const Rect wide = Rect.fromLTWH(0, 0, 400, 200);
      final Rect inWide = cellRect(const GridCell(0, 0), size: 4, box: wide);
      expect(inWide.width, closeTo(inWide.height, 1e-9));
      expect(inWide.width, closeTo(50, 1e-9),
          reason: 'squared off the width would give 100 and spill the box');

      // And the last row must still land inside the box.
      final Rect last = cellRect(const GridCell(3, 3), size: 4, box: wide);
      expect(last.bottom, lessThanOrEqualTo(wide.bottom + 1e-9));
    });

    test('a cell outside the board is refused', () {
      expect(() => cellRect(const GridCell(3, 0), size: 3, box: _box),
          throwsRangeError);
      expect(() => cellRect(const GridCell(0, -1), size: 3, box: _box),
          throwsRangeError);
    });
  });

  group('a cage outlines itself', () {
    test('a single cell is bordered on all four sides', () {
      final List<CageEdges> edges = cageEdges(_cage(<List<int>>[
        <int>[1, 1]
      ]));

      expect(edges, hasLength(1));
      expect(edges.single.top, isTrue);
      expect(edges.single.right, isTrue);
      expect(edges.single.bottom, isTrue);
      expect(edges.single.left, isTrue);
    });

    test('a horizontal pair shares one edge and borders the rest', () {
      final List<CageEdges> edges =
          cageEdges(_cage(<List<int>>[<int>[0, 0], <int>[0, 1]]));

      expect(edges.first.right, isFalse, reason: 'they touch here');
      expect(edges.last.left, isFalse, reason: 'and here');
      expect(edges.first.left, isTrue);
      expect(edges.last.right, isTrue);
      expect(edges.every((CageEdges e) => e.top && e.bottom), isTrue);
    });

    test('an L keeps its inner corner open', () {
      //  ██
      //  █
      final List<CageEdges> edges = cageEdges(
        _cage(<List<int>>[<int>[0, 0], <int>[0, 1], <int>[1, 0]]),
      );
      final CageEdges corner =
          edges.firstWhere((CageEdges e) => e.cell == const GridCell(0, 0));

      expect(corner.right, isFalse);
      expect(corner.bottom, isFalse);
      expect(corner.top, isTrue);
      expect(corner.left, isTrue);
    });

    test('two cells that do not touch each get four edges', () {
      final List<CageEdges> edges =
          cageEdges(_cage(<List<int>>[<int>[0, 0], <int>[2, 2]]));

      expect(edges, hasLength(2));
      expect(
        edges.every((CageEdges e) => e.top && e.right && e.bottom && e.left),
        isTrue,
      );
    });

    test('a cell enclosed by its own cage draws nothing', () {
      // A plus shape: the centre touches cage cells on all four sides.
      final List<CageEdges> edges = cageEdges(_cage(<List<int>>[
        <int>[0, 1], <int>[1, 0], <int>[1, 1], <int>[1, 2], <int>[2, 1],
      ]));

      expect(
        edges.any((CageEdges e) => e.cell == const GridCell(1, 1)),
        isFalse,
        reason: 'the centre has no boundary and should not be in the list',
      );
      expect(edges, hasLength(4));
    });

    test('the outline is in reading order, whatever the set order', () {
      final List<CageEdges> edges = cageEdges(_cage(<List<int>>[
        <int>[2, 0], <int>[0, 1], <int>[1, 3],
      ]));

      expect(
        edges.map((CageEdges e) => '${e.cell.row},${e.cell.col}').toList(),
        <String>['0,1', '1,3', '2,0'],
      );
    });

    test('an empty cage outlines nothing', () {
      expect(cageEdges(<GridCell>{}), isEmpty);
    });
  });

  group('a cage labels its first corner', () {
    test('topmost, then leftmost', () {
      expect(
        cageLabelAnchor(_cage(<List<int>>[<int>[1, 0], <int>[0, 2], <int>[0, 1]])),
        const GridCell(0, 1),
      );
    });

    test('the anchor does not move when the cells are listed differently', () {
      // A label that wandered with insertion order would move between runs.
      final Set<GridCell> a = _cage(<List<int>>[<int>[2, 2], <int>[1, 1]]);
      final Set<GridCell> b = _cage(<List<int>>[<int>[1, 1], <int>[2, 2]]);
      expect(cageLabelAnchor(a), cageLabelAnchor(b));
    });

    test('two cages never claim the same cell', () {
      // Cages are disjoint by construction, so their anchors are too — this is
      // the property that lets the renderer draw a label per cage without
      // checking for collisions.
      final Set<GridCell> left = _cage(<List<int>>[<int>[0, 0], <int>[1, 0]]);
      final Set<GridCell> right = _cage(<List<int>>[<int>[0, 1], <int>[1, 1]]);
      expect(cageLabelAnchor(left), isNot(cageLabelAnchor(right)));
    });

    test('an empty cage has no corner', () {
      expect(() => cageLabelAnchor(<GridCell>{}), throwsArgumentError);
    });
  });

  group('a label sits inside its cell', () {
    test('near the top-left, never on the border', () {
      final Rect cell = cellRect(const GridCell(1, 1), size: 3, box: _box);
      final origin = labelOrigin(cell);

      expect(origin.dx, greaterThan(cell.left));
      expect(origin.dy, greaterThan(cell.top));
      expect(origin.dx, lessThan(cell.center.dx));
      expect(origin.dy, lessThan(cell.center.dy));
    });
  });
}
