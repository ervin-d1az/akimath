import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'spec/math_node.dart';

/// Paints an expression that [MathNode] has laid out.
///
/// This is the adapter half and it holds no geometry decisions. It does three
/// things the spec cannot: resolves the text scaler, measures glyph advances
/// with a `TextPainter`, and turns a [MathFace] and a [MathTone] into a real
/// family and colour. Everything about *where* things go came from the spec.
///
/// The size is nominal. It is scaled here before the spec sees it, because the
/// spec answers about painted pixels — Spike B found a rule that read correctly
/// at `textScaler` 1.0 and visibly thin at 1.3 precisely because the two were
/// confused.
class MathView extends StatelessWidget {
  const MathView({super.key, required this.node, this.size = defaultNumeral});

  /// The largest numeral on a solve screen.
  ///
  /// Three documents disagree — 84, 76 and 70. 76 is what both documents that
  /// show a real solve screen use; 84 is a teaching item with no dot strip and
  /// therefore more room, and 70 is one later revision of one screen.
  static const double defaultNumeral = 76;

  final MathNode node;

  /// Nominal size, before text scaling.
  final double size;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final MathBox box = MathNode.layout(
      node,
      metrics: MathMetrics.brand,
      size: scaler.scale(size),
      measure: _measure,
    );

    return SizedBox(
      width: box.width,
      height: box.height,
      child: Stack(children: _render(box, 0, 0)),
    );
  }

  /// Advance width of [text] at [size], from the font itself.
  ///
  /// The scaler is already applied to [size] by the caller, so this must not
  /// apply it again — hence `TextScaler.noScaling` rather than the default.
  static double _measure(String text, double size) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: BrandText.numeral(size)),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }

  /// Flattens the box tree into positioned children.
  List<Widget> _render(MathBox box, double x, double y) {
    final List<Widget> out = <Widget>[];

    final MathLeaf? leaf = box.leaf;
    if (leaf != null) {
      out.add(
        Positioned(
          left: x,
          top: y,
          // Deliberately unsized. Forcing the box to the spec's height makes
          // the paragraph fill it while the glyph stays wherever its own line
          // metrics put it — which is how a rule ends up nowhere near centred
          // and no assertion on the forced rect can see it. Left free, the
          // paragraph's own box *is* the spec's box, and any disagreement
          // between the two becomes visible to a test.
          child: Text(
            leaf.text,
            // Already scaled: the spec was handed painted pixels and the
            // layout is built from them, so scaling again would double it.
            textScaler: TextScaler.noScaling,
            style: _styleFor(leaf),
          ),
        ),
      );
    }

    final Rect? rule = box.rule;
    if (rule != null) {
      out.add(
        Positioned(
          left: x + rule.left,
          top: y + rule.top,
          width: rule.width,
          height: rule.height,
          child: const ColoredBox(color: BrandColors.ink),
        ),
      );
    }

    for (final PlacedBox child in box.children) {
      out.addAll(_render(child.box, x + child.dx, y + child.dy));
    }
    return out;
  }

  TextStyle _styleFor(MathLeaf leaf) {
    final Color color = switch (leaf.tone) {
      MathTone.ink => BrandColors.ink,
      MathTone.muted => BrandColors.muted,
    };

    final FontMetrics metrics = MathMetrics.brand.forFace(leaf.face);

    // The brand's text styles set `height: 1`, which is right for a headline
    // and wrong here: it collapses the line box to the font size, while the
    // layout is built on the font's own ascent plus descent. Restoring the
    // natural ratio puts the baseline exactly where the spec said it is —
    // Darumadrop's ascent alone is 1.16 em, so the difference is 27 px at 76
    // and the denominator ends up sitting on the rule.
    final double naturalLine = metrics.ascentRatio + metrics.descentRatio;

    final TextStyle base = switch (leaf.face) {
      MathFace.display => BrandText.numeral(leaf.size),
      MathFace.textHeavy => BrandText.action(size: leaf.size).copyWith(
          fontWeight: FontWeight.w800,
          fontVariations: const <FontVariation>[FontVariation('wght', 800)],
        ),
    };

    return base.copyWith(color: color, height: naturalLine);
  }
}
