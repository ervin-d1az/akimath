import 'package:akimath_app/design/brand/spec/brand_shapes.dart';
import 'package:akimath_app/design/icons/spec/nav_glyph_spec.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fork, counted.
///
/// `f0-brand-icons`' rule D2 forbids redrawing a digest glyph by eye. These two
/// are drawn by eye, deliberately, because the bottom bar needed marks and the
/// digests are not reachable — so the exception is listed here with a number
/// against it. A third hand-drawn glyph fails this test, which is the point:
/// it should take a decision, not a habit.
void main() {
  final Map<String, BrandDrawing> drawn = <String, BrandDrawing>{
    'home': NavGlyphSpec.home,
    'settings': NavGlyphSpec.settings,
  };

  test('exactly two glyphs are drawn here rather than transcribed', () {
    expect(drawn.keys.toList()..sort(), <String>['home', 'settings']);
    // ignore: avoid_print
    print('  nav glyphs · ${drawn.length} drawn by hand, pending the digests');
  });

  group('both marks can be tinted', () {
    test('every mark is a stroke, because only a stroke takes a colour', () {
      // `InkShape` outlines in `BrandColors.ink` and takes no colour, so a
      // filled part could not follow the tab's selected state while the rest
      // did. The bar tints by rebuilding each stroke; anything else would pass
      // through at the wrong colour and nobody would notice until a screenshot.
      for (final MapEntry<String, BrandDrawing> entry in drawn.entries) {
        expect(
          entry.value.marks.every((BrandMark m) => m is InkStroke),
          isTrue,
          reason: entry.key,
        );
      }
    });
  });

  group('they fit the box they claim', () {
    test('nothing is drawn outside the viewBox', () {
      // A stroke that leaves the box is clipped by the painter's scaling and
      // shows up as a mark that looks thinner on one side than the other.
      for (final MapEntry<String, BrandDrawing> entry in drawn.entries) {
        final BrandDrawing drawing = entry.value;
        for (final BrandMark mark in drawing.marks) {
          if (mark is! InkStroke) {
            continue;
          }
          final List<Offset> points = <Offset>[
            mark.start,
            for (final PathStep step in mark.steps)
              if (step is LineTo) step.end,
          ];
          for (final Offset p in points) {
            expect(drawing.viewBox.contains(p), isTrue,
                reason: '${entry.key}: $p is outside ${drawing.viewBox}');
          }
        }
      }
    });

    test('and each uses most of it, so the two look the same size', () {
      // Two marks in one bar drawn at different scales is the kind of thing
      // nobody sees and everybody feels.
      for (final MapEntry<String, BrandDrawing> entry in drawn.entries) {
        final List<Offset> points = <Offset>[
          for (final BrandMark mark in entry.value.marks)
            if (mark is InkStroke) ...<Offset>[
              mark.start,
              for (final PathStep step in mark.steps)
                if (step is LineTo) step.end,
            ],
        ];
        final double width = points.map((Offset p) => p.dx).reduce(_max) -
            points.map((Offset p) => p.dx).reduce(_min);
        final double height = points.map((Offset p) => p.dy).reduce(_max) -
            points.map((Offset p) => p.dy).reduce(_min);
        expect(width, greaterThan(14), reason: entry.key);
        expect(height, greaterThan(12), reason: entry.key);
      }
    });
  });
}

double _max(double a, double b) => a > b ? a : b;
double _min(double a, double b) => a < b ? a : b;
