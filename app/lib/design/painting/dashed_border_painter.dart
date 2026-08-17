import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'spec/dash_spec.dart';

/// Paints the segments [DashSpec] computed, around a rounded rectangle.
///
/// This is the adapter: it measures the rounded rect, asks the spec how to cut
/// that length, and strokes the pieces. **Every decision is above the line in
/// `spec/`; every effect is below it here.**
///
/// No `MaskFilter`, no blur, ever. `no_blurred_shadow_test.dart` asserts that
/// for the pumped tree — and the reason this painter and that assertion land in
/// the same change is that a border moving into a `CustomPainter` leaves the
/// gate's reach unless the gate is widened at the same time (D22).
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.dash,
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final DashSpec dash;
  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke so the outline sits inside the box rather than
    // straddling its edge — the same convention `Border.all` follows.
    final double half = strokeWidth / 2;
    final RRect outline = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        half,
        half,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = switch (dash.cap) {
        DashCap.butt => StrokeCap.butt,
        DashCap.round => StrokeCap.round,
      };

    final Path path = Path()..addRRect(outline);
    for (final ui.PathMetric metric in path.computeMetrics()) {
      for (final DashSegment segment
          in dash.segments(pathLength: metric.length)) {
        canvas.drawPath(
          metric.extractPath(segment.start, segment.end),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.dash != dash ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}

/// The dashed outline a puzzle cage carries.
///
/// Cages are `f6-puzzles`, phases away. These numbers live here because they
/// are a property of the outline geometry and they are in the design digests
/// today — recorded where the geometry lives, so F6 consumes a tested figure
/// rather than re-deriving it from a mock six phases later (design D4).
class CageOutline {
  const CageOutline({
    required this.dash,
    required this.strokeWidth,
    required this.radius,
    required this.inset,
  });

  /// The rule drawn on a board's cell edges. A cage must clear it.
  static const double cellHairline = 1.5;

  static const CageOutline kenKen = CageOutline(
    dash: DashSpec.kenKenCage,
    strokeWidth: BrandShape.borderWidthSmallSurface,
    radius: 10,
    inset: 5,
  );

  static const CageOutline killer = CageOutline(
    dash: DashSpec.killerCage,
    strokeWidth: BrandShape.borderWidthSmallSurface,
    radius: 9,
    inset: 6,
  );

  final DashSpec dash;
  final double strokeWidth;
  final double radius;

  /// How far inside the cell block the outline sits.
  final double inset;
}
