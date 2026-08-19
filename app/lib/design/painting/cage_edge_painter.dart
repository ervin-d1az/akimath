import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../puzzle/spec/board_geometry.dart' show CageEdges;
import 'spec/dash_spec.dart';

/// A cage's boundary, dashed, on the sides that are on it.
///
/// **The board is the only thing that gets a thick ink outline.**
/// `reactivos-puzzles.md` says so in as many words — *"El contorno grueso se
/// reserva para el objeto (el tablero). Dentro, la jerarquía deja de ser grosor
/// y pasa a ser peso, color y trazo"* — and lists four levels: the board at
/// 3 px ink, cells at a 1.5 px hairline, **the cage at 2.5 px dashed pink**,
/// and a Killer block at 3 px solid ink.
///
/// The code drew cages in ink at 3 px, which is the board's own treatment: a
/// cage read as a second object stacked on the first, and on a board where most
/// cells touch a cage boundary that is most of the grid drawn in the heaviest
/// stroke the app has.
///
/// **Per edge rather than per box**, because a cage is a union of cells and
/// only its outer sides are on the boundary — which `cageOutline` already
/// works out from set membership.
class CageEdgePainter extends CustomPainter {
  const CageEdgePainter({
    required this.edges,
    required this.dash,
    required this.color,
    required this.strokeWidth,
  });

  final CageEdges edges;
  final DashSpec dash;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (!edges.hasAny) {
      return;
    }

    // Inset by half the stroke, so the line sits inside the cell rather than
    // straddling its edge — the convention `Border.all` and
    // `DashedBorderPainter` both follow, and what keeps two adjacent cages from
    // drawing one fat line between them.
    final double half = strokeWidth / 2;
    final double left = half;
    final double top = half;
    final double right = size.width - half;
    final double bottom = size.height - half;

    final Path path = Path();
    if (edges.top) {
      path
        ..moveTo(left, top)
        ..lineTo(right, top);
    }
    if (edges.right) {
      path
        ..moveTo(right, top)
        ..lineTo(right, bottom);
    }
    if (edges.bottom) {
      path
        ..moveTo(right, bottom)
        ..lineTo(left, bottom);
    }
    if (edges.left) {
      path
        ..moveTo(left, bottom)
        ..lineTo(left, top);
    }

    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = switch (dash.cap) {
        DashCap.butt => StrokeCap.butt,
        DashCap.round => StrokeCap.round,
      };

    // One metric per side, so each edge starts its dash from its own corner —
    // a single run around the whole outline would put a gap wherever a side
    // happens to end mid-dash.
    for (final ui.PathMetric metric in path.computeMetrics()) {
      for (final DashSegment segment
          in dash.segments(pathLength: metric.length)) {
        canvas.drawPath(metric.extractPath(segment.start, segment.end), paint);
      }
    }
  }

  @override
  bool shouldRepaint(CageEdgePainter oldDelegate) =>
      oldDelegate.edges.top != edges.top ||
      oldDelegate.edges.right != edges.right ||
      oldDelegate.edges.bottom != edges.bottom ||
      oldDelegate.edges.left != edges.left ||
      oldDelegate.dash != dash ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
