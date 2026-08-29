import 'package:akimath_app/design/puzzle/cage_edge_painter.dart';
import 'package:akimath_app/design/puzzle/spec/board_geometry.dart';
import 'package:akimath_app/design/puzzle/spec/cage_outline.dart';
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

CageEdgePainter _painter(
  CageEdges edges, {
  CageOutline outline = CageOutline.kenKen,
}) =>
    CageEdgePainter(edges: edges, outline: outline);

/// The colour of every stroke the painter put on a canvas, as packed ARGB.
///
/// Packed rather than as a `Color`: a colour that has been through a `Paint`
/// comes back with the same channels and does not compare equal to the token,
/// so `==` would fail on two identical pinks.
List<int> _paint(CageEdges edges, {CageOutline outline = CageOutline.kenKen}) {
  final PaintRecorder recorder = PaintRecorder();
  _painter(edges, outline: outline).paint(recorder, const Size(60, 60));
  return recorder.calls;
}

/// Every distinct cap the painter asked a real `Paint` for.
///
/// Read off the `Paint` rather than off the outline: the assertion this
/// replaces read `CageOutline.killer.dash.cap` and passed while nothing on any
/// screen painted a round cap at all.
Set<StrokeCap> _caps(CageOutline outline) {
  final PaintRecorder recorder = PaintRecorder();
  _painter(
    _edges(top: true, right: true, bottom: true, left: true),
    outline: outline,
  ).paint(recorder, const Size(60, 60));
  return recorder.caps.toSet();
}

/// The widths the painter asked for, distinct.
Set<double> _widths(CageOutline outline) {
  final PaintRecorder recorder = PaintRecorder();
  _painter(_edges(top: true), outline: outline)
      .paint(recorder, const Size(60, 60));
  return recorder.widths.toSet();
}

/// Records the drawing calls a painter makes. A stand-in for a real `Canvas`,
/// so a test can ask "did it draw anything" without a golden file.
class PaintRecorder implements Canvas {
  final List<int> calls = <int>[];
  final List<StrokeCap> caps = <StrokeCap>[];
  final List<double> widths = <double>[];

  @override
  void drawPath(Path path, Paint paint) {
    calls.add(paint.color.toARGB32());
    caps.add(paint.strokeCap);
    widths.add(paint.strokeWidth);
  }

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

  group('it strokes the outline it was handed, and nothing of its own', () {
    // The defect this painter's signature now prevents: it used to take a
    // pattern, a colour and a width, so each of the two call sites chose them
    // — and both chose KenKen's, which is why a Killer board drew a `6 4`
    // dash and `DashSpec.killerCage` reached no screen.
    test('a KenKen cage is capped square', () {
      expect(_caps(CageOutline.kenKen), <StrokeCap>{StrokeCap.butt});
    });

    test('a Killer cage is capped round, which is what makes it read as dots',
        () {
      expect(_caps(CageOutline.killer), <StrokeCap>{StrokeCap.round});
    });

    test('the two patterns put down different amounts of ink', () {
      // `2 on / 5 off` over the same path is more, shorter runs than `6 / 4`,
      // so a painter that ignored the pattern would report the same count.
      final int kenKen = _paint(_edges(top: true)).length;
      final int killer =
          _paint(_edges(top: true), outline: CageOutline.killer).length;

      expect(killer, greaterThan(kenKen));
    });

    test('a miniature strokes thinner than the board it teaches', () {
      expect(_widths(CageOutline.kenKen), <double>{BrandShape.borderWidthCage});
      expect(
        _widths(CageOutline.kenKen.miniature),
        <double>{BrandShape.borderWidthHairline},
      );
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

    test('a changed outline is a repaint', () {
      expect(
        _painter(_edges(top: true), outline: CageOutline.killer)
            .shouldRepaint(_painter(_edges(top: true))),
        isTrue,
      );
    });

    test('an outline rebuilt from the same values is not', () {
      // `miniature` returns a new instance on every build. Compared by
      // identity this would repaint every reference diagram every frame.
      expect(
        _painter(_edges(top: true), outline: CageOutline.kenKen.miniature)
            .shouldRepaint(
          _painter(_edges(top: true), outline: CageOutline.kenKen.miniature),
        ),
        isFalse,
      );
    });
  });
}
