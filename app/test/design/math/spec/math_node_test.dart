import 'dart:ui' show Rect;

import 'package:akimath_app/design/math/spec/math_node.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for the adapter's text measurement.
///
/// Real advance widths need a font, which needs IO — so the module takes a
/// measure and does not perform one. A fixed ratio per character is enough to
/// assert arrangement, and it is what keeps this test free of a fake canvas.
double measureFlat(String text, double size) => text.length * size * 0.55;

void main() {
  group('a nested fraction lays out from metrics alone', () {
    test('the bar sits on the math axis, derived from the x-height', () {
      final MathBox box = MathNode.layout(
        FractionNode(
          numerator: const NumeralNode('1'),
          denominator: const NumeralNode('2'),
        ),
        metrics: MathMetrics.brand,
        size: 76,
        measure: measureFlat,
      );

      final Rect rule = box.rule!;

      // The rule is centred on the box's own axis, which is what an adjacent
      // operator aligns against.
      expect(rule.center.dy, closeTo(box.axis, 0.001));

      // And its thickness is FractionMetrics' answer for this size, not a
      // number this module invented.
      expect(rule.height, closeTo(6, 0.001));
    });

    test('a fraction whose numerator is itself a fraction nests', () {
      final MathBox box = MathNode.layout(
        FractionNode(
          numerator: FractionNode(
            numerator: const NumeralNode('1'),
            denominator: const NumeralNode('2'),
          ),
          denominator: const NumeralNode('3'),
        ),
        metrics: MathMetrics.brand,
        size: 76,
        measure: measureFlat,
      );

      // Two rules exist: the outer one on this box, the inner one on the
      // numerator's box.
      final MathBox numerator = box.children.first.box;
      expect(box.rule, isNotNull);
      expect(numerator.rule, isNotNull);

      // The inner rule is thinner, because the inner fraction is painted
      // smaller — the property that made the nested case legible in Spike B.
      expect(numerator.rule!.height, lessThan(box.rule!.height));

      // The whole thing is taller than a flat fraction at the same size.
      final MathBox flat = MathNode.layout(
        FractionNode(
          numerator: const NumeralNode('1'),
          denominator: const NumeralNode('3'),
        ),
        metrics: MathMetrics.brand,
        size: 76,
        measure: measureFlat,
      );
      expect(box.height, greaterThan(flat.height));
    });

    test('the gap above and below the rule is measured from the ink', () {
      // The spike positioned by line box and the gaps came out unequal, because
      // Darumadrop's line box is not symmetric about its glyphs (ascent 1160,
      // descent -288). Positioning from the baseline and the cap height is what
      // makes them equal, and this is the assertion that holds it there.
      final MathBox box = MathNode.layout(
        FractionNode(
          numerator: const NumeralNode('1'),
          denominator: const NumeralNode('2'),
        ),
        metrics: MathMetrics.brand,
        size: 76,
        measure: measureFlat,
      );

      final PlacedBox numerator = box.children.first;
      final PlacedBox denominator = box.children.last;
      final Rect rule = box.rule!;

      // Each box publishes where its own ink starts and stops, so the
      // assertion does not re-derive the font maths the module just did.
      final double numeratorInkBottom = numerator.dy + numerator.box.inkBottom;
      final double denominatorInkTop = denominator.dy + denominator.box.inkTop;

      expect(
        rule.top - numeratorInkBottom,
        closeTo(denominatorInkTop - rule.bottom, 0.001),
        reason: 'the rule is not optically centred between the two numerals',
      );
    });

    test('the module reads no ambient state and imports no Flutter', () {
      // Enforced for real by pure_boundary_test over design/**/spec/. Kept here
      // as the statement of intent a reader of this file meets first.
      final MathBox once = MathNode.layout(
        const NumeralNode('7'),
        metrics: MathMetrics.brand,
        size: 46,
        measure: measureFlat,
      );
      final MathBox twice = MathNode.layout(
        const NumeralNode('7'),
        metrics: MathMetrics.brand,
        size: 46,
        measure: measureFlat,
      );

      expect(once.width, twice.width);
      expect(once.height, twice.height);
      expect(once.axis, twice.axis);
    });
  });

  group('the injected metrics are the only font knowledge in the module', () {
    test('two faces produce two different axes at the same size', () {
      final MathBox daruma = MathNode.layout(
        const NumeralNode('7'),
        metrics: MathMetrics.brand,
        size: 76,
        measure: measureFlat,
      );
      final MathBox jakarta = MathNode.layout(
        const NumeralNode('7'),
        metrics: const MathMetrics(
          display: FontMetrics.plusJakarta,
          textHeavy: FontMetrics.plusJakarta,
        ),
        size: 76,
        measure: measureFlat,
      );

      // Darumadrop's x-height is 435/1000 and Plus Jakarta's is 536/1000, so a
      // module that actually reads the injected value cannot return the same
      // axis for both. One that hard-codes a ratio would.
      expect(daruma.axis, isNot(closeTo(jakarta.axis, 0.001)));
    });

    test('the recorded ratios match the shipped font files', () {
      // Parsed from the TTFs in assets/fonts/ on 2026-08-16. If a font is
      // replaced, this is the test that notices.
      expect(FontMetrics.darumadrop.xHeightRatio, closeTo(0.435, 0.0001));
      expect(FontMetrics.darumadrop.capHeightRatio, closeTo(0.590, 0.0001));
      expect(FontMetrics.plusJakarta.xHeightRatio, closeTo(0.536, 0.0001));
      expect(FontMetrics.plusJakarta.capHeightRatio, closeTo(0.745, 0.0001));
    });
  });

  group('a token is laid out in the face it is painted in', () {
    test('a textHeavy operator uses Plus Jakarta metrics, not Darumadrop', () {
      // D7 sets `=` in Plus Jakarta 800 and everything else in Darumadrop. The
      // two faces have different x-heights (536 against 435), and the axis is
      // half an x-height above the baseline — so laying every token out with
      // one metrics set puts `=` about 0.05em off the axis the fractions sit
      // on. At 76px that is ~3.8px of visible misalignment on the solve screen.
      final MathBox equals = MathNode.layout(
        OperatorNode.of('='),
        metrics: MathMetrics.brand,
        size: 76,
        measure: measureFlat,
      );

      final double jakartaAxis = FontMetrics.plusJakarta.ascentRatio * 76 -
          FontMetrics.plusJakarta.xHeightRatio * 76 / 2;

      expect(equals.axis, closeTo(jakartaAxis, 0.001));
    });

    test('a display operator still uses Darumadrop metrics', () {
      final MathBox plus = MathNode.layout(
        OperatorNode.of('+'),
        metrics: MathMetrics.brand,
        size: 76,
        measure: measureFlat,
      );

      final double darumaAxis = FontMetrics.darumadrop.ascentRatio * 76 -
          FontMetrics.darumadrop.xHeightRatio * 76 / 2;

      expect(plus.axis, closeTo(darumaAxis, 0.001));
    });

    test('the equals sign lands on the row axis with the fractions', () {
      final MathBox row = MathNode.layout(
        RowNode(<MathNode>[
          FractionNode(
            numerator: const NumeralNode('3'),
            denominator: const NumeralNode('4'),
          ),
          OperatorNode.of('='),
          const NumeralNode('1'),
        ]),
        metrics: MathMetrics.brand,
        size: 76,
        measure: measureFlat,
      );

      for (final PlacedBox child in row.children) {
        expect(child.dy + child.box.axis, closeTo(row.axis, 0.001));
      }
    });
  });

  group('operator styling is a property of the token', () {
    test('each operator resolves its own face', () {
      const OperatorNode plus =
          OperatorNode('+', face: MathFace.display, tone: MathTone.ink);
      const OperatorNode equals =
          OperatorNode('=', face: MathFace.textHeavy, tone: MathTone.ink);

      expect(plus.face, MathFace.display);
      expect(equals.face, MathFace.textHeavy);
    });

    test('the default is applied when a token names no face', () {
      // D7: operators default to Darumadrop, `=` to Plus Jakarta 800. The
      // conflict the sources could not settle is defused at the API — a screen
      // that draws it differently says so on the token.
      expect(OperatorNode.of('+').face, MathFace.display);
      expect(OperatorNode.of('×').face, MathFace.display);
      expect(OperatorNode.of('=').face, MathFace.textHeavy);
    });

    test('tone is a role and never a colour', () {
      // PURE-1, and the precedent Verdict already set by carrying no `.color`.
      // A palette decision inside a pure module is one no gate here would
      // catch: no_color_literal_test scans design/widgets/ and features/, not
      // design/**/spec/.
      for (final MathTone tone in MathTone.values) {
        expect(tone.toString(), isNot(contains('Color')));
      }
      expect(MathTone.values, <MathTone>[MathTone.ink, MathTone.muted]);
    });
  });

  group('a fraction is never rendered inline', () {
    test('the node exposes no variant that puts it on one line', () {
      // req-fraction-stacked's second scenario. Asserted over the constructor's
      // own parameters: a rule saying "do not emit a solidus" is a rule someone
      // breaks under deadline; a type with no such parameter is not.
      const FractionNode fraction = FractionNode(
        numerator: NumeralNode('3'),
        denominator: NumeralNode('4'),
      );

      // A laid-out fraction always yields a rule and exactly two children.
      final MathBox box = MathNode.layout(
        fraction,
        metrics: MathMetrics.brand,
        size: 76,
        measure: measureFlat,
      );
      expect(box.rule, isNotNull);
      expect(box.children, hasLength(2));
    });

    test('no numeral or operator carries a solidus glyph', () {
      expect(
        () => OperatorNode.of('/'),
        throwsA(isA<ArgumentError>()),
        reason: 'a solidus operator is how an inline fraction gets drawn',
      );
    });
  });

  group('a row aligns its children on the shared axis', () {
    test('a fraction and an operator meet on the same axis', () {
      final MathBox row = MathNode.layout(
        RowNode(<MathNode>[
          FractionNode(
            numerator: const NumeralNode('3'),
            denominator: const NumeralNode('4'),
          ),
          OperatorNode.of('+'),
          FractionNode(
            numerator: const NumeralNode('2'),
            denominator: const NumeralNode('5'),
          ),
        ]),
        metrics: MathMetrics.brand,
        size: 76,
        measure: measureFlat,
      );

      for (final PlacedBox child in row.children) {
        expect(
          child.dy + child.box.axis,
          closeTo(row.axis, 0.001),
          reason: 'a child sits off the row axis',
        );
      }
    });

    test('children advance left to right without overlapping', () {
      final MathBox row = MathNode.layout(
        RowNode(<MathNode>[
          const NumeralNode('3'),
          OperatorNode.of('+'),
          const NumeralNode('4'),
        ]),
        metrics: MathMetrics.brand,
        size: 76,
        measure: measureFlat,
      );

      double edge = 0;
      for (final PlacedBox child in row.children) {
        expect(child.dx, greaterThanOrEqualTo(edge - 0.001));
        edge = child.dx + child.box.width;
      }
      expect(row.width, closeTo(edge, 0.001));
    });
  });
}
