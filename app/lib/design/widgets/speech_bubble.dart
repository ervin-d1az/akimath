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
  static const double _tailHeight = 16;

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
                  offset: Offset(4, 6),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(text, style: BrandText.body()),
          ),
          Positioned(
            left: 22,
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

/// The bubble's tail: an outlined triangle whose top edge is painted over in
/// surface color so it reads as one shape with the bubble above it.
class _BubbleTail extends CustomPainter {
  const _BubbleTail();

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 26;
    final double sy = size.height / 18;

    final Path triangle = Path()
      ..moveTo(3 * sx, 2 * sy)
      ..lineTo(23 * sx, 2 * sy)
      ..lineTo(11 * sx, 16 * sy)
      ..close();

    canvas.drawPath(triangle, Paint()..color = BrandColors.surface);
    canvas.drawPath(
      triangle,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = BrandColors.ink
        ..strokeWidth = 3 * sx
        ..strokeJoin = StrokeJoin.round,
    );
    // Hide the seam where the tail meets the bubble's own border.
    canvas.drawRect(
      Rect.fromLTWH(5 * sx, -2 * sy, 16 * sx, 4 * sy),
      Paint()..color = BrandColors.surface,
    );
  }

  @override
  bool shouldRepaint(_BubbleTail oldDelegate) => false;
}
