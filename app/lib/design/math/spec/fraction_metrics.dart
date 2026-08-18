/// The geometry of a fraction's rule, derived from the size the numerals are
/// actually painted at.
///
/// **The parameter is the *effective* size, not the nominal one.** A caller that
/// passes the size it asked for, rather than the size after text scaling, gets a
/// bar that is correct at `textScaler` 1.0 and visibly thin at 1.3 — the numerals
/// grow and the rule does not. Spike B saw exactly that; resolving the scaler is
/// the adapter's job, and this module answers only about painted pixels.
///
/// Pure: it takes a number and returns numbers. No Flutter import, no
/// `MediaQuery`, no `TextScaler`.
library;

/// One row the design measured: a numeral size and the rule it carries.
typedef _Row = ({double size, double thickness, double minWidth});

/// The three rows the design states, and the only numbers here that are not
/// derived. Everything between and above them is interpolated from these.
///
/// They are held in one visible table rather than as branches, because they are
/// measurements and a reader has to be able to check them against the design
/// without reading control flow.
const List<_Row> _measured = <_Row>[
  (size: 22, thickness: 3, minWidth: 26),
  (size: 46, thickness: 4, minWidth: 36),
  (size: 76, thickness: 6, minWidth: 58),
];

class FractionMetrics {
  const FractionMetrics({
    required this.barThickness,
    required this.minBarWidth,
  });

  /// Resolves the rule for a numeral painted at [effectiveSize].
  ///
  /// Between the measured rows the two figures interpolate linearly, so the
  /// rule keeps its proportion as text scales. Above the largest row the last
  /// slope continues — 76 x 1.3 = 98.8 is inside the range the app is gated to
  /// support, and a value there must not collapse back onto 76's bar.
  ///
  /// Below the smallest row both figures **clamp** rather than extrapolate.
  /// Nothing in the corpus draws a fraction under 22 px, and a rule thinner
  /// than the hairlines it sits among would disappear rather than read as thin.
  factory FractionMetrics.forSize(double effectiveSize) {
    final _Row smallest = _measured.first;
    if (effectiveSize <= smallest.size) {
      return FractionMetrics(
        barThickness: smallest.thickness,
        minBarWidth: smallest.minWidth,
      );
    }

    for (int i = 1; i < _measured.length; i++) {
      final _Row upper = _measured[i];
      if (effectiveSize <= upper.size) {
        return _between(_measured[i - 1], upper, effectiveSize);
      }
    }

    // Past the largest row: continue the slope of the last segment.
    return _between(
      _measured[_measured.length - 2],
      _measured.last,
      effectiveSize,
    );
  }

  /// Linear interpolation between two measured rows, extrapolating when
  /// [size] lies beyond [upper].
  static FractionMetrics _between(_Row lower, _Row upper, double size) {
    final double t = (size - lower.size) / (upper.size - lower.size);
    return FractionMetrics(
      barThickness:
          lower.thickness + t * (upper.thickness - lower.thickness),
      minBarWidth: lower.minWidth + t * (upper.minWidth - lower.minWidth),
    );
  }

  /// How thick the rule is drawn.
  final double barThickness;

  /// The rule's floor width. A one-digit numerator over a one-digit denominator
  /// would otherwise draw a rule barely wider than a glyph.
  final double minBarWidth;
}
