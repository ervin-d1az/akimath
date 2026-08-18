import 'package:akimath_app/design/math/spec/fraction_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the bar geometry scales with the numeral', () {
    // The three rows the design measured. Asserted as pairs rather than as a
    // formula: a formula checked against itself cannot go red.
    test('76 px', () {
      final FractionMetrics metrics = FractionMetrics.forSize(76);
      expect(metrics.barThickness, 6);
      expect(metrics.minBarWidth, 58);
    });

    test('46 px', () {
      final FractionMetrics metrics = FractionMetrics.forSize(46);
      expect(metrics.barThickness, 4);
      expect(metrics.minBarWidth, 36);
    });

    test('22 px', () {
      final FractionMetrics metrics = FractionMetrics.forSize(22);
      expect(metrics.barThickness, 3);
      expect(metrics.minBarWidth, 26);
    });
  });

  group('the geometry is continuous between the measured rows', () {
    // Spike B, finding 2. A step function passes every assertion above and is
    // still wrong: text scaling puts the effective size *between* the rows, and
    // a step serves 98.8 the same 6px bar it gives 76 — visibly too thin, see
    // `spike-b/scaled-1.3.png`.

    test('a size between 46 and 76 interpolates both figures', () {
      // 61 is the midpoint: thickness 4 -> 6 gives 5, width 36 -> 58 gives 47.
      final FractionMetrics metrics = FractionMetrics.forSize(61);
      expect(metrics.barThickness, closeTo(5, 0.001));
      expect(metrics.minBarWidth, closeTo(47, 0.001));
    });

    test('a size between 22 and 46 interpolates both figures', () {
      // 34 is the midpoint: thickness 3 -> 4 gives 3.5, width 26 -> 36 gives 31.
      final FractionMetrics metrics = FractionMetrics.forSize(34);
      expect(metrics.barThickness, closeTo(3.5, 0.001));
      expect(metrics.minBarWidth, closeTo(31, 0.001));
    });

    test('above the largest measured row the geometry keeps growing', () {
      // 76 x 1.3 = 98.8, the gated maximum. A step function returns 6 here.
      final FractionMetrics metrics = FractionMetrics.forSize(76 * 1.3);
      expect(metrics.barThickness, greaterThan(6));
      expect(metrics.minBarWidth, greaterThan(58));
    });

    test('below the smallest measured row the geometry stops shrinking', () {
      // Nothing in the corpus draws below 22, and a bar thinner than the
      // hairline it sits near would disappear. Clamp rather than extrapolate.
      final FractionMetrics metrics = FractionMetrics.forSize(10);
      expect(metrics.barThickness, 3);
      expect(metrics.minBarWidth, 26);
    });
  });

  group('the bar holds its proportion under text scaling', () {
    // Spike B, finding 1 — stated as the property the user actually sees rather
    // than as an implementation detail. This is the assertion a step function
    // cannot pass: at 98.8 it yields 6/98.8 = 0.061 against 6/76 = 0.079, a
    // 23% collapse, which is the artefact visible in the spike capture.
    test('the thickness-to-size ratio survives 1.0 -> 1.3', () {
      const double nominal = 76;
      final double unscaled =
          FractionMetrics.forSize(nominal).barThickness / nominal;
      final double scaled = FractionMetrics.forSize(nominal * 1.3).barThickness /
          (nominal * 1.3);

      expect(
        scaled,
        closeTo(unscaled, unscaled * 0.1),
        reason: 'the bar thinned relative to the numeral as text scaled up',
      );
    });

    test('the ratio holds across every step of the supported range', () {
      for (double scale = 1.0; scale <= 1.3; scale += 0.05) {
        const double nominal = 76;
        final double ratio =
            FractionMetrics.forSize(nominal * scale).barThickness /
                (nominal * scale);
        expect(
          ratio,
          closeTo(6 / nominal, (6 / nominal) * 0.1),
          reason: 'proportion broke at scale $scale',
        );
      }
    });
  });

  group('the parameter is the size the glyph is actually painted at', () {
    test('the same nominal size at two scales yields two geometries', () {
      // The spec never sees a TextScaler — the adapter resolves it. What this
      // pins is that the module answers about the *painted* size, so handing it
      // a nominal value is a caller bug and not a silent no-op.
      final FractionMetrics atOne = FractionMetrics.forSize(76);
      final FractionMetrics atOneThree = FractionMetrics.forSize(76 * 1.3);

      expect(atOneThree.barThickness, isNot(atOne.barThickness));
    });
  });
}
