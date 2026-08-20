import 'dart:io';

import 'package:akimath_app/design/brand/spec/brand_shapes.dart';
import 'package:akimath_app/design/icons/spec/nav_glyph_spec.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fork, counted.
///
/// `f0-brand-icons`' rule D2 forbids redrawing a digest glyph by eye. These
/// three are drawn by eye, deliberately, because the bottom bar needed marks
/// and the digests are not reachable — so the exception is listed here with a
/// number against it. Another hand-drawn glyph fails this test, which is the
/// point: it should take a decision, not a habit.
///
/// **The count is taken from the source, not from the list below.** It used to
/// be the list, which counted whatever somebody remembered to add — so the file
/// could grow a mark and the gate that exists to notice would not. `Avance`'s
/// mark is the one that proved it: it went in, the bar drew it, and every test
/// stayed green.
void main() {
  final Map<String, BrandDrawing> drawn = <String, BrandDrawing>{
    'home': NavGlyphSpec.home,
    'progress': NavGlyphSpec.progress,
    'settings': NavGlyphSpec.settings,
  };

  test('exactly three glyphs are drawn here rather than transcribed', () {
    expect(drawn.keys.toList()..sort(), <String>['home', 'progress', 'settings']);
    // ignore: avoid_print
    print('  nav glyphs · ${drawn.length} drawn by hand, pending the digests');
  });

  test('and the list is the whole file, not the part somebody remembered', () {
    // The list above is hand-written, so it counts what a human added to it. A
    // mark added to the spec and not to the list would leave this gate green
    // while the fork grew — which is exactly what happened when `Avance` got
    // its own. The source is the authority for *how many*.
    final File source =
        File('lib/design/icons/spec/nav_glyph_spec.dart');
    expect(source.existsSync(), isTrue, reason: source.absolute.path);

    final Iterable<RegExpMatch> declared = RegExp(
      r'static final BrandDrawing (\w+)',
    ).allMatches(source.readAsStringSync());

    expect(declared.map((RegExpMatch m) => m.group(1)!).toSet(), drawn.keys.toSet());
  });

  group('every mark can be tinted', () {
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

    test('and each uses most of it, so they look the same size', () {
      // Marks in one bar drawn at different scales is the kind of thing
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
