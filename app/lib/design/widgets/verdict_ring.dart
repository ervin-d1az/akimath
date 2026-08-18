import 'package:flutter/widgets.dart';

import '../icons/brand_icon.dart';
import '../painting/dashed_border_painter.dart';
import '../painting/spec/dash_spec.dart';
import '../tokens/tokens.dart';
import 'spec/verdict.dart';

/// Paints a [Verdict]: an outline whose *pattern* carries the result, and a
/// glyph inside it.
///
/// The hue is real information for a reader who can see it, so it is applied —
/// but never as the only channel. Strip the colour and the two rings still
/// differ, which is the property `verdict_test.dart` asserts.
class VerdictRing extends StatelessWidget {
  const VerdictRing(this.verdict, {super.key, this.size = defaultSize, this.color});

  /// Twice the 22px circle the corpus draws on the progress strip.
  ///
  /// The strip's dot is an indicator glanced at in a row of eight; this is the
  /// single verdict a player looks straight at after answering. Same component,
  /// deliberately larger — the strip passes 22 when it lands.
  static const double defaultSize = 44;

  final Verdict verdict;
  final double size;

  /// Overrides the role colour. Used by the greyscale test.
  final Color? color;

  Color get _resolved =>
      color ??
      switch (verdict) {
        Verdict.correct => BrandColorRole.success.color,
        Verdict.wrong => BrandColorRole.error.color,
      };

  @override
  Widget build(BuildContext context) {
    final bool dashed = verdict.outline == VerdictOutline.dashed;

    final Widget body = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Identical for both verdicts on purpose: the distinction must come
        // from the pattern and the glyph, never from the fill.
        color: BrandColors.surface,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(size / 2),
        border: dashed
            ? null
            : Border.all(color: _resolved, width: BrandShape.borderWidth),
      ),
      child: Center(
        child: BrandIcon(verdict.glyph, size: size * 0.5, color: _resolved),
      ),
    );

    if (!dashed) {
      return body;
    }

    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        dash: DashSpec.locked,
        color: _resolved,
        strokeWidth: BrandShape.borderWidth,
        radius: size / 2,
      ),
      child: body,
    );
  }
}
