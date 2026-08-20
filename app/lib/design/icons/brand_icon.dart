import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'spec/brand_glyph.dart';
import 'spec/icon_paths.dart';

// Re-exported so a call site that draws a glyph does not need two imports. The
// enum itself stays in `spec/`, importing nothing — see the note there.
export 'spec/brand_glyph.dart';

/// A brand glyph, at a size and a colour the caller chooses.
///
/// **The stand-in characters are gone.** Every glyph rendered as `▲`, `⚙`, `‹`
/// or `⌫` until the design digests became reachable; they were a deliberate,
/// visible placeholder and never an approximation of the real mark. What
/// replaces them is `icon_paths.dart` — the design's own `d` strings, verbatim,
/// with the stroke weight each glyph was assigned. **No call site changed**,
/// which is the whole reason the seam was drawn here rather than screens
/// reaching for `Text('⌫')`.
///
/// **[size] is the height, and the width follows the glyph.** Almost every mark
/// in the set is square and this is invisible for them. `mapsTo` is 30×24 in
/// the design, and squaring it would either distort the arrow or letterbox it —
/// visible immediately in `BeforeAfterCounters`, where it sits between two
/// numerals.
///
/// **It does not scale with the text setting**, which the stand-ins did because
/// they were `Text`. An icon that grew inside a fixed 48px key would burst it.
class BrandIcon extends StatelessWidget {
  const BrandIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color = BrandColors.ink,
  });

  final BrandGlyph glyph;

  /// The drawn height. The width comes from the glyph's own coordinate space.
  final double size;

  final Color color;

  @override
  Widget build(BuildContext context) {
    final IconSpec spec = iconPaths[glyph]!;
    final double scale = size / spec.viewBox.height;

    return SizedBox(
      width: spec.viewBox.width * scale,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(spec: spec, color: color),
      ),
    );
  }
}

/// Strokes a glyph's transcribed geometry into the box it was given.
///
/// **ADAPTER.** It holds no geometry and no palette: the paths and the weight
/// come from the spec, the colour from the caller.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.spec, required this.color});

  final IconSpec spec;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.height / spec.viewBox.height;

    final Paint brush = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      // **Scaled with the glyph.** A fixed stroke would make a 16px mark read
      // as a heavy blot and a 40px one as a hairline; the design states the
      // weight in viewBox units for exactly that reason.
      ..strokeWidth = spec.strokeWidth * scale
      ..strokeCap = spec.round ? StrokeCap.round : StrokeCap.butt
      ..strokeJoin = spec.round ? StrokeJoin.round : StrokeJoin.miter;

    canvas.save();
    canvas.scale(scale);
    for (final Path path in spec.paths) {
      // Scaling the canvas rather than the path so the stroke is not scaled
      // twice — `strokeWidth` above is already in painted pixels.
      canvas.drawPath(path, brush..strokeWidth = spec.strokeWidth);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.spec != spec || old.color != color;
}
