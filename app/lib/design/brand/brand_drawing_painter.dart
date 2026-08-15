import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../tokens/brand_colors.dart';
import 'spec/brand_shapes.dart';

/// Turns a [BrandDrawing] into draw calls.
///
/// This is the only place in the brand layer that touches a `Canvas`. It holds
/// no artwork of its own: move a coordinate here and nothing changes, because
/// every coordinate lives in the spec.
class BrandDrawingPainter extends CustomPainter {
  const BrandDrawingPainter(this.drawing);

  final BrandDrawing drawing;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect box = drawing.viewBox;
    if (box.width <= 0 || box.height <= 0) {
      return;
    }

    final double scale =
        math.min(size.width / box.width, size.height / box.height);
    final double dx = (size.width - box.width * scale) / 2 - box.left * scale;
    final double dy = (size.height - box.height * scale) / 2 - box.top * scale;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    for (final BrandMark mark in drawing.marks) {
      switch (mark) {
        case InkStroke():
          _paintStroke(canvas, mark);
        case InkShape():
          _paintShape(canvas, mark);
        case InkRect():
          _paintRect(canvas, mark);
        case InkOval():
          _paintOval(canvas, mark);
        case InkDot():
          _paintDot(canvas, mark);
      }
    }

    canvas.restore();
  }

  void _paintStroke(Canvas canvas, InkStroke stroke) {
    final Path path = _pathFrom(stroke.start, stroke.steps);

    canvas.drawPath(path, _strokePaint(stroke.color, stroke.width));

    final Color? coreColor = stroke.coreColor;
    final double? coreWidth = stroke.coreWidth;
    if (coreColor != null && coreWidth != null) {
      canvas.drawPath(path, _strokePaint(coreColor, coreWidth));
    }
  }

  void _paintShape(Canvas canvas, InkShape shape) {
    final Path path = _pathFrom(shape.start, shape.steps)..close();
    canvas.drawPath(path, Paint()..color = shape.fill);
    if (shape.inkWidth > 0) {
      canvas.drawPath(path, _strokePaint(BrandColors.ink, shape.inkWidth));
    }
  }

  void _paintRect(Canvas canvas, InkRect rect) {
    final RRect rrect = RRect.fromRectAndRadius(rect.rect, rect.radius);
    canvas.drawRRect(rrect, Paint()..color = rect.fill);
    if (rect.inkWidth > 0) {
      canvas.drawRRect(rrect, _strokePaint(BrandColors.ink, rect.inkWidth));
    }
  }

  void _paintOval(Canvas canvas, InkOval oval) {
    canvas.drawOval(oval.bounds, Paint()..color = oval.fill);
    if (oval.hasOutline) {
      canvas.drawOval(oval.bounds, _strokePaint(BrandColors.ink, oval.inkWidth));
    }
  }

  void _paintDot(Canvas canvas, InkDot dot) {
    canvas.drawCircle(
      dot.center,
      dot.radius,
      Paint()..color = dot.fill.withValues(alpha: dot.opacity),
    );
    if (dot.hasOutline) {
      canvas.drawCircle(
        dot.center,
        dot.radius,
        _strokePaint(BrandColors.ink, dot.inkWidth),
      );
    }
  }

  Path _pathFrom(Offset start, List<PathStep> steps) {
    final Path path = Path()..moveTo(start.dx, start.dy);
    for (final PathStep step in steps) {
      switch (step) {
        case LineTo():
          path.lineTo(step.end.dx, step.end.dy);
        case QuadTo():
          path.quadraticBezierTo(
            step.control.dx,
            step.control.dy,
            step.end.dx,
            step.end.dy,
          );
        case CubicTo():
          path.cubicTo(
            step.controlA.dx,
            step.controlA.dy,
            step.controlB.dx,
            step.controlB.dy,
            step.end.dx,
            step.end.dy,
          );
      }
    }
    return path;
  }

  /// Every stroke in the system is round-capped and round-joined. There is no
  /// second option.
  Paint _strokePaint(Color color, double width) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  @override
  bool shouldRepaint(BrandDrawingPainter oldDelegate) =>
      !identical(oldDelegate.drawing, drawing);
}
