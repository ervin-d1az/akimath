import 'package:akimath_app/design/painting/cage_edge_painter.dart';
import 'package:akimath_app/design/painting/spec/dash_spec.dart';
import 'package:akimath_app/design/puzzle/spec/board_geometry.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

CageEdges _edges({
  bool top = false,
  bool right = false,
  bool bottom = false,
  bool left = false,
}) =>
    CageEdges(
      cell: const GridCell(0, 0),
      top: top,
      right: right,
      bottom: bottom,
      left: left,
    );

CageEdgePainter _painter(CageEdges edges) => CageEdgePainter(
      edges: edges,
      dash: DashSpec.kenKenCage,
      color: BrandColors.pink,
      strokeWidth: BrandShape.borderWidthCage,
    );

/// The colour of every stroke the painter put on a canvas, as packed ARGB.
///
/// Packed rather than as a `Color`: a colour that has been through a `Paint`
/// comes back with the same channels and does not compare equal to the token,
/// so `==` would fail on two identical pinks.
List<int> _paint(CageEdges edges) {
  final PaintRecorder recorder = PaintRecorder();
  _painter(edges).paint(recorder, const Size(60, 60));
  return recorder.calls;
}

/// Records the drawing calls a painter makes. A stand-in for a real `Canvas`,
/// so a test can ask "did it draw anything" without a golden file.
class PaintRecorder implements Canvas {
  final List<int> calls = <int>[];

  @override
  void drawPath(Path path, Paint paint) => calls.add(paint.color.toARGB32());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('it draws only the sides that are on the boundary', () {
    test('a cell inside its cage draws nothing', () {
      // Every neighbour is in the same cage, so there is no boundary here and
      // a line would be a cage drawn through its own middle.
      expect(_paint(_edges()), isEmpty);
    });

    test('one side draws one run of dashes', () {
      final List<int> one = _paint(_edges(top: true));
      final List<int> two = _paint(_edges(top: true, left: true));

      expect(one, isNotEmpty);
      expect(two.length, greaterThan(one.length),
          reason: 'a second side should add dashes, not replace them');
    });

    test('every side draws', () {
      final List<int> all =
          _paint(_edges(top: true, right: true, bottom: true, left: true));
      final List<int> one = _paint(_edges(top: true));

      expect(all.length, greaterThan(one.length * 3));
    });
  });

  group('it draws the cage in the cage colour', () {
    test('pink, never ink', () {
      // The defect: cages were drawn in ink at the board's own 3 px, so a cage
      // read as a second object stacked on the first.
      final List<int> drawn =
          _paint(_edges(top: true, right: true, bottom: true, left: true));

      expect(drawn, isNotEmpty);
      expect(drawn.toSet(), <int>{BrandColors.pink.toARGB32()});
      expect(drawn, isNot(contains(BrandColors.ink.toARGB32())));
    });
  });

  group('it repaints when it should', () {
    test('a changed side is a repaint', () {
      expect(
        _painter(_edges(top: true)).shouldRepaint(_painter(_edges())),
        isTrue,
      );
    });

    test('the same edges are not', () {
      expect(
        _painter(_edges(top: true)).shouldRepaint(_painter(_edges(top: true))),
        isFalse,
      );
    });
  });
}
