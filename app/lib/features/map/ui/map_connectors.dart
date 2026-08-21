import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/widgets.dart';

import '../../../design/painting/spec/dash_spec.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/spec/mastery_level.dart';
import '../policy/map_layout.dart';
import 'mastery_skin.dart';

/// The lines between the topics.
///
/// **It knows no geometry of its own.** Every coordinate is the centre of a
/// `Rect` `MapLayout` computed, so the connectors cannot drift from the boxes
/// they join — the same split `BrandDrawingPainter` has from `aki_spec.dart`
/// (PURE-2). Where the ink goes along a dashed line is `DashSpec`'s arithmetic,
/// which is why nothing here calls `computeMetrics`.
///
/// **A connector to a locked topic is dashed**, exactly as the design draws it:
/// `stroke-dasharray="9 9"` in muted, against solid ink everywhere else. It is
/// the same shape-not-hue rule the nodes follow (BRD-1) — the road to somewhere
/// you cannot go yet is drawn as an unfinished road.
class MapConnectors extends CustomPainter {
  const MapConnectors({
    required this.boxes,
    required this.edges,
    required this.lockedNodes,
  });

  final List<Rect> boxes;
  final List<MapEdge> edges;

  /// The indices of the topics that cannot be opened.
  final Set<int> lockedNodes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final MapEdge edge in edges) {
      final Offset from = boxes[edge.from].center;
      final Offset to = boxes[edge.to].center;
      if (lockedNodes.contains(edge.to)) {
        _strokeDashed(canvas, from, to);
      } else {
        canvas.drawLine(from, to, _paint(BrandColors.ink));
      }
    }
  }

  void _strokeDashed(Canvas canvas, Offset from, Offset to) {
    final double length = (to - from).distance;
    if (length <= 0) {
      return;
    }
    final Paint paint = _paint(MasterySkin.of(MasteryLevel.locked).ink);
    for (final DashSegment segment
        in DashSpec.locked.segments(pathLength: length)) {
      canvas.drawLine(
        Offset.lerp(from, to, segment.start / length)!,
        Offset.lerp(from, to, segment.end / length)!,
        paint,
      );
    }
  }

  Paint _paint(Color color) => Paint()
    ..color = color
    ..strokeWidth = MapLayout.connectorWidth
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  @override
  bool shouldRepaint(MapConnectors old) =>
      !listEquals(old.boxes, boxes) ||
      !setEquals(old.lockedNodes, lockedNodes) ||
      !listEquals(
        old.edges.map(_name).toList(),
        edges.map(_name).toList(),
      );

  /// An edge as a comparable value. `MapEdge` carries no equality of its own —
  /// it is a pair of indices and giving it one for a repaint check would be a
  /// type shaped by its caller.
  static String _name(MapEdge edge) => '${edge.from}>${edge.to}';
}
