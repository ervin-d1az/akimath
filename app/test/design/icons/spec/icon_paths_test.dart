import 'dart:ui';

import 'package:akimath_app/design/icons/spec/brand_glyph.dart';
import 'package:akimath_app/design/icons/spec/icon_paths.dart';
import 'package:flutter_test/flutter_test.dart';

/// The transcription, checked against the space it claims to live in.
///
/// **Bounds, not "it parsed".** A path parser's failure mode is a plausible
/// wrong curve. A glyph that collapsed to a point or spilled past its own
/// viewBox is what a wrong transcription looks like, and both are visible in
/// the rectangle the geometry occupies.
void main() {
  group('every named glyph is transcribed', () {
    test('the set is complete, and the count is reported', () {
      final Set<BrandGlyph> missing =
          BrandGlyph.values.toSet().difference(iconPaths.keys.toSet());

      // ignore: avoid_print
      expect(
        missing,
        isEmpty,
        reason: 'no transcription for: ${missing.map((BrandGlyph g) => g.name).join(', ')}',
      );
      expect(
        iconPaths.length,
        BrandGlyph.values.length,
        reason: 'glyphs transcribed → ${iconPaths.length} '
            'of ${BrandGlyph.values.length}',
      );
      // PROC-10: a gate that could pass over nothing is not a gate.
      expect(iconPaths.length, greaterThan(0));
    });
  });

  group('each glyph draws inside its own viewBox', () {
    for (final MapEntry<BrandGlyph, IconSpec> entry in iconPaths.entries) {
      final String name = entry.key.name;
      final IconSpec spec = entry.value;

      test('$name parses every path it declares', () {
        expect(spec.d, isNotEmpty);
        expect(spec.paths, hasLength(spec.d.length));
      });

      test('$name fits its declared coordinate space', () {
        // A stroke is drawn centred on the path, so half of it falls outside;
        // the design's own SVGs are drawn to sit within the box allowing for
        // that. Half a stroke of tolerance is exactly the slack the format has.
        final double slack = spec.strokeWidth / 2 + 0.01;
        Rect box = spec.paths.first.getBounds();
        for (final Path path in spec.paths.skip(1)) {
          box = box.expandToInclude(path.getBounds());
        }

        expect(box.left, greaterThanOrEqualTo(-slack), reason: '$name spills left');
        expect(box.top, greaterThanOrEqualTo(-slack), reason: '$name spills up');
        expect(box.right, lessThanOrEqualTo(spec.viewBox.width + slack),
            reason: '$name spills right');
        expect(box.bottom, lessThanOrEqualTo(spec.viewBox.height + slack),
            reason: '$name spills down');
      });

      test('$name is not a point', () {
        // A transcription that lost its commands parses and draws nothing. The
        // one legitimately tiny mark in the set is `alert`'s dot, `h.01`, and
        // it shares a path with the stem above it.
        Rect box = spec.paths.first.getBounds();
        for (final Path path in spec.paths.skip(1)) {
          box = box.expandToInclude(path.getBounds());
        }
        expect(box.longestSide, greaterThan(spec.viewBox.longestSide * 0.4),
            reason: '$name occupies almost none of its box');
      });

      test('$name carries a stroke the design assigned', () {
        // Between the board hairline and the outline weight. A glyph at 0 or at
        // 8 is a transcription slip, not a design decision.
        expect(spec.strokeWidth, greaterThanOrEqualTo(1.5));
        expect(spec.strokeWidth, lessThanOrEqualTo(4));
      });
    }
  });

  group('the shapes the set is built on', () {
    test('mapsTo is the one glyph that is not square', () {
      // `13 › 1` in `BeforeAfterCounters` renders this. Squaring a 30×24 arrow
      // either distorts it or letterboxes it, and both are wrong everywhere it
      // appears.
      final Iterable<BrandGlyph> oblong = iconPaths.entries
          .where((MapEntry<BrandGlyph, IconSpec> e) =>
              e.value.viewBox.width != e.value.viewBox.height)
          .map((MapEntry<BrandGlyph, IconSpec> e) => e.key);

      expect(oblong, <BrandGlyph>[BrandGlyph.mapsTo]);
      expect(iconPaths[BrandGlyph.mapsTo]!.viewBox, const Size(30, 24));
    });

    test('submit is heavier than the backspace beside it', () {
      // They sit on one keypad, and the design made them differ. A single
      // global stroke weight would flatten that.
      expect(
        iconPaths[BrandGlyph.submit]!.strokeWidth,
        greaterThan(iconPaths[BrandGlyph.backspace]!.strokeWidth),
      );
    });

    test('back and forward point opposite ways', () {
      // **Not a mirror test, because they are not mirrored.** The design draws
      // `back` across x 7–14 and `forward` across 9–16 — the same 7-unit
      // chevron, offset one unit off centre in each direction rather than
      // reflected about x=12. Asserting a perfect mirror would be asserting an
      // idealisation the transcription is right not to have.
      //
      // What must hold is that they point apart, which bounds cannot see: a
      // chevron drawn backwards occupies the same rectangle. The tangent at the
      // start of the stroke can.
      final Rect back = iconPaths[BrandGlyph.back]!.paths.first.getBounds();
      final Rect forward = iconPaths[BrandGlyph.forward]!.paths.first.getBounds();
      expect(back.size.width, closeTo(forward.size.width, 0.01));
      expect(back.size.height, closeTo(forward.size.height, 0.01));

      double openingDx(BrandGlyph glyph) => iconPaths[glyph]!
          .paths
          .first
          .computeMetrics()
          .first
          .getTangentForOffset(0)!
          .vector
          .dx;

      expect(openingDx(BrandGlyph.back), lessThan(0), reason: 'back opens leftward');
      expect(openingDx(BrandGlyph.forward), greaterThan(0),
          reason: 'forward opens rightward');
    });
  });
}
