import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// What Aki says, in a bubble with a hard shadow and a pointed tail.
///
/// She says one short line and never the same one twice. The bubble carries no
/// avatar of its own — it is always placed beside her.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    this.maxWidth = 180,
  });

  final String text;
  final double maxWidth;

  static const double _tailWidth = 26;

  /// **18, not 16.** The design's tail is a `26×18` box whose apex sits at
  /// `y=16`, so the last two units are the overshoot that lets the seam be
  /// covered. Drawing it 16 tall squashed the whole path by a ninth and left
  /// the patch too short to reach the bubble's border.
  static const double _tailHeight = 18;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Room for the tail, which hangs below the bubble's box.
      padding: const EdgeInsets.only(bottom: _tailHeight),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: BrandColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: BrandColors.ink,
                width: BrandShape.borderWidth,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: BrandColors.ink,
                  offset: BrandShape.shadowButton,
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(text, style: BrandText.body()),
          ),
          Positioned(
            // `left:26` in `pantallas-base.md`; the code had 22.
            left: 26,
            bottom: -_tailHeight,
            width: _tailWidth,
            height: _tailHeight,
            child: CustomPaint(painter: const _BubbleTail()),
          ),
        ],
      ),
    );
  }
}

/// The bubble's tail.
///
/// **The mouth is open.** A speech bubble's tail is not a triangle stuck
/// underneath: its inside is the bubble's inside, and the outline runs around
/// the outside of both. Drawn as a closed, fully stroked triangle it reads as a
/// separate little arrow hanging off the box — which is what a player reported.
///
/// Three passes, in this order:
///
/// 1. **Erase the bubble's border across the mouth**, between the two side
///    strokes. The design calls this the *seam patch*. Its own `h=4` was
///    measured for the SVG's coordinate space and does not cover a 3 px border
///    once the box is scaled, so this reaches further up: the point is to
///    remove the line, and a patch that removes most of it leaves exactly the
///    hairline that made the tail look detached.
/// 2. **Fill the triangle**, so the tail's inside is the same white.
/// 3. **Stroke only the two slanted sides.** Stroking the top edge as well is
///    what drew the line the patch then had to hide; not drawing it is simpler
///    than covering it.
class _BubbleTail extends CustomPainter {
  const _BubbleTail();

  /// The design's viewBox, so the path below can be read against
  /// `M3 2 L23 2 L11 16 Z` without arithmetic.
  static const double _designWidth = 26;
  static const double _designHeight = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / _designWidth;
    final double sy = size.height / _designHeight;
    final double stroke = BrandShape.borderWidth * sx;

    final Paint fill = Paint()..color = BrandColors.surface;

    // 1 — the seam. Inset horizontally by half a stroke on each side so the
    // two side strokes survive it, and taken well above the mouth so the
    // bubble's whole 3 px border goes with it.
    canvas.drawRect(
      Rect.fromLTRB(
        3 * sx + stroke / 2,
        -stroke - sy,
        23 * sx - stroke / 2,
        1 * sy,
      ),
      fill,
    );

    // 2 — the tail's own white.
    canvas.drawPath(
      Path()
        ..moveTo(3 * sx, 0)
        ..lineTo(23 * sx, 0)
        ..lineTo(11 * sx, 16 * sy)
        ..close(),
      fill,
    );

    // 3 — the two sides, open at the top. The apex keeps the design's lean:
    // x=11 of 26 is left of centre.
    canvas.drawPath(
      Path()
        ..moveTo(3 * sx, 0)
        ..lineTo(11 * sx, 16 * sy)
        ..lineTo(23 * sx, 0),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = BrandColors.ink
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(_BubbleTail oldDelegate) => false;
}
