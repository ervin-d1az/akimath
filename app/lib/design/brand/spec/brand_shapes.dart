import 'dart:ui' show Color, Offset, Rect;

import 'package:meta/meta.dart';

/// The primitives a brand drawing is described with.
///
/// This layer knows nothing about `Canvas`, `Paint`, or widgets — it is data.
/// It can be tested without rendering anything. The adapter that turns it into
/// draw calls lives in `../brand_drawing_painter.dart`.
@immutable
sealed class BrandMark {
  const BrandMark();
}

/// One segment of a stroked path.
@immutable
sealed class PathStep {
  const PathStep();

  /// Where this segment ends.
  Offset get end;
}

/// Straight line to [end].
@immutable
final class LineTo extends PathStep {
  const LineTo(this.end);

  @override
  final Offset end;
}

/// Quadratic curve with one control point.
@immutable
final class QuadTo extends PathStep {
  const QuadTo(this.control, this.end);

  final Offset control;

  @override
  final Offset end;
}

/// Cubic curve with two control points.
@immutable
final class CubicTo extends PathStep {
  const CubicTo(this.controlA, this.controlB, this.end);

  final Offset controlA;
  final Offset controlB;

  @override
  final Offset end;
}

/// A stroke drawn in ink and, optionally, overdrawn with a colored core.
///
/// This is the system's central gesture: gills and tail are drawn twice, first
/// thick in ink and then thin in color, which produces the outline without a
/// separate stroke pass.
@immutable
final class InkStroke extends BrandMark {
  const InkStroke({
    required this.start,
    required this.steps,
    required this.inkWidth,
    this.coreColor,
    this.coreWidth,
  }) : assert(
          (coreColor == null) == (coreWidth == null),
          'A core needs both a color and a width, or neither.',
        );

  /// A straight stroke from one point to another.
  factory InkStroke.line(
    Offset from,
    Offset to, {
    required double inkWidth,
    Color? coreColor,
    double? coreWidth,
  }) {
    return InkStroke(
      start: from,
      steps: <PathStep>[LineTo(to)],
      inkWidth: inkWidth,
      coreColor: coreColor,
      coreWidth: coreWidth,
    );
  }

  final Offset start;
  final List<PathStep> steps;
  final double inkWidth;
  final Color? coreColor;
  final double? coreWidth;

  /// Where the stroke ends. Gill tips anchor here.
  Offset get end => steps.isEmpty ? start : steps.last.end;

  /// A stroke has a core when a color is drawn over the ink.
  bool get hasCore => coreColor != null;
}

/// A filled oval with an ink outline.
@immutable
final class InkOval extends BrandMark {
  const InkOval({
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.fill,
    required this.inkWidth,
  });

  final Offset center;
  final double radiusX;
  final double radiusY;
  final Color fill;
  final double inkWidth;

  Rect get bounds => Rect.fromCenter(
        center: center,
        width: radiusX * 2,
        height: radiusY * 2,
      );
}

/// A filled circle. With [inkWidth] at zero it carries no outline, which is how
/// cheeks and eyes are drawn.
@immutable
final class InkDot extends BrandMark {
  const InkDot({
    required this.center,
    required this.radius,
    required this.fill,
    this.inkWidth = 0,
    this.opacity = 1,
  }) : assert(opacity >= 0 && opacity <= 1, 'Opacity out of range.');

  final Offset center;
  final double radius;
  final Color fill;
  final double inkWidth;
  final double opacity;

  bool get hasOutline => inkWidth > 0;
}

/// A complete drawing: its primitives in paint order, plus the logical box they
/// are defined on.
///
/// Order matters: the head is painted after the gills because it covers their
/// inner ends.
@immutable
final class BrandDrawing {
  const BrandDrawing({
    required this.viewBox,
    required this.marks,
  });

  /// The drawing's logical size. The adapter scales it to the real box.
  final Rect viewBox;

  final List<BrandMark> marks;
}
