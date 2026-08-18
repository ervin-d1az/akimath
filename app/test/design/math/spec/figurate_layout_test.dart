import 'package:akimath_app/design/math/spec/figurate_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a count is recognised as the figure it makes', () {
    test('the triangular numbers are, and their neighbours are not', () {
      // 1, 3, 6, 10, 15, 21 — the design's authored figures are the first four.
      for (final int n in <int>[1, 3, 6, 10, 15, 21]) {
        expect(triangularRoot(n), isNotNull, reason: '$n is triangular');
      }
      for (final int n in <int>[2, 4, 5, 7, 9, 11, 14, 16, 20, 22]) {
        expect(triangularRoot(n), isNull, reason: '$n is not triangular');
      }
    });

    test('the root is the row count, not the number', () {
      expect(triangularRoot(1), 1);
      expect(triangularRoot(3), 2);
      expect(triangularRoot(6), 3);
      expect(triangularRoot(10), 4);
    });

    test('the square numbers are, and their neighbours are not', () {
      for (final int n in <int>[1, 4, 9, 16, 25, 100]) {
        expect(squareRoot(n), isNotNull, reason: '$n is square');
      }
      for (final int n in <int>[2, 3, 5, 8, 10, 15, 24, 99, 101]) {
        expect(squareRoot(n), isNull, reason: '$n is not square');
      }
    });

    test('neither root accepts zero or a negative count', () {
      for (final int n in <int>[0, -1, -6]) {
        expect(triangularRoot(n), isNull);
        expect(squareRoot(n), isNull);
      }
    });
  });

  group('a triangle is laid out as a triangle', () {
    test('six dots make rows of one, two and three', () {
      final FigurateLayout layout = figurateLayout(6);

      expect(layout.dots, hasLength(6));

      // Grouped by y, the rows must be 1, 2, 3 — which is the whole difference
      // between a figure a learner can continue and a 3×2 block.
      final Map<String, int> perRow = <String, int>{};
      for (final Offset dot in layout.dots) {
        final String row = dot.dy.toStringAsFixed(4);
        perRow[row] = (perRow[row] ?? 0) + 1;
      }
      expect(perRow.values.toList(), <int>[1, 2, 3]);
    });

    test('each row is centred over the one below it', () {
      final FigurateLayout layout = figurateLayout(6);

      // The apex sits on the axis; without centring it would sit at the left
      // edge and the figure would read as a staircase.
      expect(layout.dots.first.dx, moreOrLessEquals(0.5, epsilon: 1e-9));

      final double lastRowLeft = layout.dots[3].dx;
      final double lastRowRight = layout.dots[5].dx;
      expect((lastRowLeft + lastRowRight) / 2,
          moreOrLessEquals(0.5, epsilon: 1e-9));
    });

    test('ten dots make four rows', () {
      final FigurateLayout layout = figurateLayout(10);
      final Set<String> rows = <String>{
        for (final Offset dot in layout.dots) dot.dy.toStringAsFixed(4),
      };

      expect(layout.dots, hasLength(10));
      expect(rows, hasLength(4));
    });
  });

  group('a square is laid out as a square', () {
    test('nine dots make three rows of three', () {
      final FigurateLayout layout = figurateLayout(9);
      final Set<String> rows = <String>{
        for (final Offset dot in layout.dots) dot.dy.toStringAsFixed(4),
      };
      final Set<String> columns = <String>{
        for (final Offset dot in layout.dots) dot.dx.toStringAsFixed(4),
      };

      expect(rows, hasLength(3));
      expect(columns, hasLength(3));
    });

    test('four is square and not triangular, so it is a 2x2', () {
      // 4 is the smallest count where the two arrangements differ, and it is
      // the one that catches the branches being tried in the wrong order.
      final FigurateLayout layout = figurateLayout(4);
      final Set<String> rows = <String>{
        for (final Offset dot in layout.dots) dot.dy.toStringAsFixed(4),
      };

      expect(layout.dots, hasLength(4));
      expect(rows, hasLength(2), reason: '4 as a triangle would need 3 rows');
    });
  });

  group('every figure stays inside its box', () {
    test('no dot, edge included, leaves the unit square', () {
      for (int count = 1; count <= 21; count++) {
        final FigurateLayout layout = figurateLayout(count);
        expect(layout.dots, hasLength(count), reason: 'count $count');

        for (final Offset dot in layout.dots) {
          expect(dot.dx - layout.radius, greaterThanOrEqualTo(-1e-9),
              reason: 'count $count spills left');
          expect(dot.dx + layout.radius, lessThanOrEqualTo(1 + 1e-9),
              reason: 'count $count spills right');
          expect(dot.dy - layout.radius, greaterThanOrEqualTo(-1e-9),
              reason: 'count $count spills above');
          expect(dot.dy + layout.radius, lessThanOrEqualTo(1 + 1e-9),
              reason: 'count $count spills below');
        }
      }
    });

    test('the radius shrinks as the count grows', () {
      // The property the design asks for by name. Without it a figure of ten
      // draws ten full-size dots and overruns the 52 px box.
      expect(figurateLayout(3).radius, lessThan(figurateLayout(1).radius));
      expect(figurateLayout(6).radius, lessThan(figurateLayout(3).radius));
      expect(figurateLayout(10).radius, lessThan(figurateLayout(6).radius));
    });

    test('dots never overlap', () {
      // Touching dots read as a blob and stop being countable, which is the
      // one thing this figure has to be.
      for (final int count in <int>[3, 6, 9, 10, 16]) {
        final FigurateLayout layout = figurateLayout(count);
        for (int i = 0; i < layout.dots.length; i++) {
          for (int j = i + 1; j < layout.dots.length; j++) {
            expect(
              (layout.dots[i] - layout.dots[j]).distance,
              greaterThan(layout.radius * 2),
              reason: 'dots $i and $j touch at count $count',
            );
          }
        }
      }
    });
  });

  group('a count that is no figure at all still draws something', () {
    test('five falls back to a block rather than throwing', () {
      // The reader refuses such a pack, so this only runs if something upstream
      // is wrong. An ugly figure beats a crash mid-round.
      final FigurateLayout layout = figurateLayout(5);
      expect(layout.dots, hasLength(5));
      expect(layout.radius, greaterThan(0));
    });

    test('zero is empty, not an error', () {
      expect(figurateLayout(0).dots, isEmpty);
    });
  });
}
