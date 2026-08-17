/// Expression layout, computed from injected font metrics.
///
/// Nothing here constructs a `Path` or touches a `Canvas`. It receives numbers
/// — an x-height, a cap height, a measured advance width — and returns boxes
/// with positions. The painter beside it turns those into ink.
///
/// **Two things this module deliberately does not know.**
///
/// It does not know how wide a glyph is: advance widths need a font, which
/// needs IO. The caller passes a [GlyphMeasure] and the arrangement is computed
/// from what it returns. That is what lets the test assert real layout with a
/// flat stand-in measure and no fake canvas.
///
/// It does not know what colour anything is. [MathTone] is a role the adapter
/// resolves, following the precedent `Verdict` already set by carrying no
/// `.color`. This matters more here than elsewhere: `dart:ui` is an allowed
/// import under a pure root, so nothing would *stop* a `Color` living in this
/// file — and `no_color_literal_test` scans `design/widgets/` and `features/`,
/// not `design/**/spec/`. The discipline is the guard.
library;

import 'dart:ui' show Rect;

import 'fraction_metrics.dart';

/// Measures the advance width of [text] painted at [size].
///
/// Supplied by the adapter, which has a `TextPainter`. Injected rather than
/// called, so this module stays a function of its inputs.
typedef GlyphMeasure = double Function(String text, double size);

/// Which face a token is set in.
///
/// A name, not a font family string: the mapping to `BrandFonts` belongs to the
/// adapter, and a family name in here would be a rendering decision in a module
/// that is supposed to hold none.
enum MathFace {
  /// Darumadrop. Numerals and, by default, operators.
  display,

  /// Plus Jakarta Sans 800. `=` by default (D7).
  textHeavy,
}

/// How emphatic a token is.
///
/// **A role, never a colour.** The adapter resolves it against `BrandColors`.
/// The value set is the two the type scale already distinguishes for text; the
/// corpus names the `tone:` parameter without enumerating it, so this is the
/// minimum that is grounded rather than invented, and it widens when a design
/// digest asks it to.
enum MathTone { ink, muted }

/// Metrics of one face, in font units over an em.
///
/// The two constants below were parsed from the TTFs in `app/assets/fonts/` on
/// 2026-08-16 rather than copied from a document. `math_node_test.dart` asserts
/// them, so replacing a font file fails a test instead of shifting every
/// fraction quietly.
class FontMetrics {
  const FontMetrics({
    required this.unitsPerEm,
    required this.xHeight,
    required this.capHeight,
    required this.ascent,
    required this.descent,
  });

  /// Darumadrop One.
  static const FontMetrics darumadrop = FontMetrics(
    unitsPerEm: 1000,
    xHeight: 435,
    capHeight: 590,
    ascent: 1160,
    descent: 288,
  );

  /// Plus Jakarta Sans.
  static const FontMetrics plusJakarta = FontMetrics(
    unitsPerEm: 1000,
    xHeight: 536,
    capHeight: 745,
    ascent: 1038,
    descent: 222,
  );

  final double unitsPerEm;
  final double xHeight;
  final double capHeight;

  /// `hhea.ascent`, positive.
  final double ascent;

  /// `hhea.descent` as a positive magnitude.
  final double descent;

  double get xHeightRatio => xHeight / unitsPerEm;
  double get capHeightRatio => capHeight / unitsPerEm;
  double get ascentRatio => ascent / unitsPerEm;
  double get descentRatio => descent / unitsPerEm;
}

/// The metrics of every face an expression can use.
///
/// A token is laid out in the face it is *painted* in. That is not a detail:
/// D7 sets `=` in Plus Jakarta and everything else in Darumadrop, the two
/// x-heights are 536 and 435 over an em, and the axis sits half an x-height
/// above the baseline — so measuring every token with one face puts `=` about
/// 0.05 em off the axis its neighbours sit on, which is a visible ~3.8 px at
/// 76 px.
class MathMetrics {
  const MathMetrics({required this.display, required this.textHeavy});

  /// The two faces this brand ships.
  static const MathMetrics brand = MathMetrics(
    display: FontMetrics.darumadrop,
    textHeavy: FontMetrics.plusJakarta,
  );

  final FontMetrics display;
  final FontMetrics textHeavy;

  FontMetrics forFace(MathFace face) => switch (face) {
        MathFace.display => display,
        MathFace.textHeavy => textHeavy,
      };
}

/// A laid-out node in its own coordinate space, origin at its top-left.
class MathBox {
  const MathBox({
    required this.width,
    required this.height,
    required this.axis,
    required this.baseline,
    required this.inkTop,
    required this.inkBottom,
    this.rule,
    this.leaf,
    this.children = const <PlacedBox>[],
  });

  final double width;
  final double height;

  /// Distance from the top of this box to its topmost ink, and to its
  /// bottommost.
  ///
  /// A box is taller than what it draws: a leaf carries the font's full ascent
  /// and descent, and digits occupy neither extreme. Stacking a fraction by box
  /// edges therefore leaves visibly unequal clearances, which is exactly what
  /// Spike B saw. Carrying the ink extents explicitly is what lets the assembly
  /// measure from the marks rather than from the boxes — and it is why a
  /// fraction can be nested inside a fraction without the parent having to know
  /// which of the two it received.
  final double inkTop;
  final double inkBottom;

  /// Distance from the top of this box to the mathematical axis — the line an
  /// adjacent token aligns against. For a numeral it is half an x-height above
  /// the baseline; for a fraction it is the centre of the rule.
  final double axis;

  /// Distance from the top of this box to the text baseline. For a composite
  /// this is the axis, which is the only sensible answer when there are two.
  final double baseline;

  /// The fraction rule, in this box's coordinates. Null unless this is a
  /// fraction.
  final Rect? rule;

  /// What to draw, when this box is a run of text rather than a composite.
  final MathLeaf? leaf;

  final List<PlacedBox> children;
}

/// What a leaf box draws.
///
/// Carried on the box rather than looked up from the node tree, so the painter
/// walks one structure instead of two in lockstep — the second walk is where a
/// renderer drifts out of agreement with the layout it is rendering.
class MathLeaf {
  const MathLeaf({
    required this.text,
    required this.face,
    required this.tone,
    required this.size,
  });

  final String text;
  final MathFace face;
  final MathTone tone;

  /// The size this run is painted at, already resolved — a nested fraction's
  /// parts are smaller than their parent's.
  final double size;
}

/// A child box and where it sits inside its parent.
class PlacedBox {
  const PlacedBox({required this.box, required this.dx, required this.dy});

  final MathBox box;
  final double dx;
  final double dy;
}

/// A node of an expression.
sealed class MathNode {
  const MathNode();

  /// The gap between a numeral's ink and the fraction rule, in x-heights.
  ///
  /// Spike B validated ~0.28 em of ink-to-rule clearance by eye at 76 px; over
  /// Darumadrop's x-height that is 0.64. Expressed in x-heights rather than ems
  /// because the requirement is stated that way and because it is the metric
  /// that tracks how large the digits actually look.
  static const double _ruleGapInXHeights = 0.64;

  /// How much the numerator and denominator shrink relative to their parent.
  ///
  /// Applies only to a fraction nested inside another. A flat fraction's parts
  /// are drawn at full size.
  static const double _nestedScale = 0.55;

  /// Lays [node] out at [size], using [metrics] for vertical placement and
  /// [measure] for horizontal extent.
  static MathBox layout(
    MathNode node, {
    required MathMetrics metrics,
    required double size,
    required GlyphMeasure measure,
  }) {
    return switch (node) {
      // A numeral is always the display face; an operator carries its own.
      NumeralNode() => _leaf(
          MathLeaf(
            text: node.digits,
            face: MathFace.display,
            tone: MathTone.ink,
            size: size,
          ),
          metrics.display,
          measure,
        ),
      OperatorNode() => _leaf(
          MathLeaf(
            text: node.glyph,
            face: node.face,
            tone: node.tone,
            size: size,
          ),
          metrics.forFace(node.face),
          measure,
        ),
      FractionNode() => _fraction(node, metrics, size, measure),
      RowNode() => _row(node, metrics, size, measure),
    };
  }

  /// A single run of text.
  ///
  /// Height is the font's own ascent-plus-descent rather than [size], so a box
  /// contains its glyph instead of clipping it — Darumadrop's ascent alone is
  /// 1.16 em.
  static MathBox _leaf(
    MathLeaf leaf,
    FontMetrics metrics,
    GlyphMeasure measure,
  ) {
    final double size = leaf.size;
    final double baseline = metrics.ascentRatio * size;
    final double height =
        (metrics.ascentRatio + metrics.descentRatio) * size;
    return MathBox(
      width: measure(leaf.text, size),
      height: height,
      axis: baseline - metrics.xHeightRatio * size / 2,
      baseline: baseline,
      // Digits and operators reach the cap height and sit on the baseline.
      inkTop: baseline - metrics.capHeightRatio * size,
      inkBottom: baseline,
      leaf: leaf,
    );
  }

  static MathBox _fraction(
    FractionNode node,
    MathMetrics metrics,
    double size,
    GlyphMeasure measure,
  ) {
    // A part that is itself a fraction is drawn smaller, which is what keeps
    // the two rules distinguishable when they stack.
    double partSize(MathNode part) =>
        part is FractionNode ? size * _nestedScale : size;

    final MathBox numerator = layout(
      node.numerator,
      metrics: metrics,
      size: partSize(node.numerator),
      measure: measure,
    );
    final MathBox denominator = layout(
      node.denominator,
      metrics: metrics,
      size: partSize(node.denominator),
      measure: measure,
    );

    final FractionMetrics rule = FractionMetrics.forSize(size);
    final double gap =
        metrics.display.xHeightRatio * size * _ruleGapInXHeights;
    final double width = <double>[
      numerator.width,
      denominator.width,
      rule.minBarWidth,
    ].reduce((double a, double b) => a > b ? a : b);

    // Vertical assembly, measured from the ink rather than from the box edges.
    // Both parts publish their own ink extents, so this works unchanged whether
    // a part is a numeral or another fraction — the parent never asks which.
    final double ruleTop = numerator.inkBottom + gap;
    final double ruleBottom = ruleTop + rule.barThickness;

    // Place the denominator so its topmost ink clears the rule by the same gap.
    final double denominatorTop = ruleBottom + gap - denominator.inkTop;

    final double axis = ruleTop + rule.barThickness / 2;
    final double ruleWidth = _ruleWidth(width, rule);

    return MathBox(
      width: width,
      height: denominatorTop + denominator.height,
      axis: axis,
      baseline: axis,
      inkTop: numerator.inkTop,
      inkBottom: denominatorTop + denominator.inkBottom,
      rule: Rect.fromLTWH(
        (width - ruleWidth) / 2,
        ruleTop,
        ruleWidth,
        rule.barThickness,
      ),
      children: <PlacedBox>[
        PlacedBox(
          box: numerator,
          dx: (width - numerator.width) / 2,
          dy: 0,
        ),
        PlacedBox(
          box: denominator,
          dx: (width - denominator.width) / 2,
          dy: denominatorTop,
        ),
      ],
    );
  }

  /// The rule spans the box, floored at the design's minimum.
  static double _ruleWidth(double boxWidth, FractionMetrics rule) =>
      boxWidth > rule.minBarWidth ? boxWidth : rule.minBarWidth;

  static MathBox _row(
    RowNode node,
    MathMetrics metrics,
    double size,
    GlyphMeasure measure,
  ) {
    final List<MathBox> boxes = node.children
        .map(
          (MathNode child) => layout(
            child,
            metrics: metrics,
            size: size,
            measure: measure,
          ),
        )
        .toList();

    // Every child hangs from the shared axis, so the row's axis is the deepest
    // one and its height is whatever the tallest child needs on each side.
    final double axis = boxes
        .map((MathBox b) => b.axis)
        .reduce((double a, double b) => a > b ? a : b);
    final double below = boxes
        .map((MathBox b) => b.height - b.axis)
        .reduce((double a, double b) => a > b ? a : b);

    final List<PlacedBox> placed = <PlacedBox>[];
    double x = 0;
    for (final MathBox box in boxes) {
      placed.add(PlacedBox(box: box, dx: x, dy: axis - box.axis));
      x += box.width;
    }

    return MathBox(
      width: x,
      height: axis + below,
      axis: axis,
      baseline: axis,
      inkTop: placed
          .map((PlacedBox p) => p.dy + p.box.inkTop)
          .reduce((double a, double b) => a < b ? a : b),
      inkBottom: placed
          .map((PlacedBox p) => p.dy + p.box.inkBottom)
          .reduce((double a, double b) => a > b ? a : b),
      children: placed,
    );
  }
}

/// A run of digits.
final class NumeralNode extends MathNode {
  const NumeralNode(this.digits);

  final String digits;
}

/// An operator, carrying its own styling (D7).
final class OperatorNode extends MathNode {
  const OperatorNode(this.glyph, {required this.face, required this.tone});

  /// The operator with this project's default styling for it.
  ///
  /// Throws on a solidus: an inline fraction is not something this module
  /// declines to draw, it is something it has no way to express.
  factory OperatorNode.of(String glyph) {
    if (glyph == '/' || glyph == '⁄') {
      throw ArgumentError.value(
        glyph,
        'glyph',
        'a solidus would render a fraction inline; use FractionNode',
      );
    }
    return OperatorNode(
      glyph,
      face: glyph == '=' ? MathFace.textHeavy : MathFace.display,
      tone: MathTone.ink,
    );
  }

  final String glyph;
  final MathFace face;
  final MathTone tone;
}

/// A stacked fraction. There is no inline variant, by construction.
final class FractionNode extends MathNode {
  const FractionNode({required this.numerator, required this.denominator});

  final MathNode numerator;
  final MathNode denominator;
}

/// Operands and operators on one line.
final class RowNode extends MathNode {
  const RowNode(this.children);

  final List<MathNode> children;
}
