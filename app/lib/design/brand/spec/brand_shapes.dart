import 'dart:ui' show Color, Offset, Radius, Rect;

import 'package:meta/meta.dart';

import '../../tokens/brand_colors.dart';

/// The primitives a brand drawing is described with.
///
/// This layer knows nothing about `Canvas`, `Paint`, or widgets — it is data.
/// It can be tested without rendering anything. The adapter that turns it into
/// draw calls lives in `../brand_drawing_painter.dart`.
@immutable
sealed class BrandMark {
  const BrandMark();
}

/// One segment of a path.
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

/// An open stroke, optionally overdrawn with a colored core.
///
/// Drawing a line twice — thick in ink, then thinner in color — is how the
/// system produces an outlined stroke without a second pass. Aki's tail is the
/// main user; when the tail uncoils on a wrong answer, the new curl grows back
/// as a second [InkStroke] whose core is green.
@immutable
final class InkStroke extends BrandMark {
  const InkStroke({
    required this.start,
    required this.steps,
    required this.width,
    this.color = BrandColors.ink,
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
    required double width,
    Color color = BrandColors.ink,
  }) {
    return InkStroke(
      start: from,
      steps: <PathStep>[LineTo(to)],
      width: width,
      color: color,
    );
  }

  final Offset start;
  final List<PathStep> steps;

  /// Width of the outer pass.
  final double width;

  /// Color of the outer pass. Ink for outlines; the body color for the mouth,
  /// which is a highlight cut into the dark muzzle rather than an outline.
  final Color color;

  final Color? coreColor;
  final double? coreWidth;

  /// Where the stroke ends.
  Offset get end => steps.isEmpty ? start : steps.last.end;

  /// A stroke has a core when a second color is drawn over the first.
  bool get hasCore => coreColor != null;
}

/// A closed, filled path with an ink outline. Ears and collar-tag facets.
@immutable
final class InkShape extends BrandMark {
  const InkShape({
    required this.start,
    required this.steps,
    required this.fill,
    required this.inkWidth,
  });

  final Offset start;
  final List<PathStep> steps;
  final Color fill;
  final double inkWidth;
}

/// A rounded rectangle with a fill and an ink outline. Muzzle, legs, collar.
@immutable
final class InkRect extends BrandMark {
  const InkRect({
    required this.rect,
    required this.radius,
    required this.fill,
    required this.inkWidth,
  });

  final Rect rect;
  final Radius radius;
  final Color fill;
  final double inkWidth;
}

/// A filled oval. With [inkWidth] at zero it carries no outline, which is how
/// the nose is drawn.
@immutable
final class InkOval extends BrandMark {
  const InkOval({
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.fill,
    this.inkWidth = 0,
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

  bool get hasOutline => inkWidth > 0;
}

/// A filled circle. Eyes, catchlights, the collar tag's bead, and the dust the
/// old tail curl leaves behind.
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
/// Order matters: the ears are painted before the head so the head covers
/// their bases, and the catchlights after the eyes so they sit on top.
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
