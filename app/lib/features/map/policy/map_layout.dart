/// Where the topics of the map sit, and which of them are joined.
///
/// **PURE** — a count and a width in, boxes and edges out. No `Canvas`, no
/// widget, no `BuildContext`; `SkillMapScreen` positions what this returns and
/// `MapConnectors` strokes between the boxes it is handed.
///
/// It returns `Rect`s it computed rather than shadow offsets, which is the
/// standing `figurate_layout.dart` already has in this repository: geometry
/// *is* the content here. Nothing in this file is a hard-shadow offset —
/// [shadowReserve] reads one off `BrandShape` rather than naming a number.
///
/// **The row pattern is the design's own, and the branching is a drawing
/// convention over a real order.** `05 Mapa de habilidades` lays nine nodes out
/// as rows of 2, 1, 1, 2, 1, 2 and joins every node of a row to every node of
/// the next. The order the nodes arrive in is real — it is the order the pack
/// introduces its families in, which is the order a player meets them — and
/// this file is how a linear order gets drawn as a ladder instead of a list.
library;

import 'dart:ui' show Rect, Size;

import 'package:meta/meta.dart';

import '../../../design/tokens/brand_shape.dart';

/// One connector, named by the two nodes it joins.
///
/// It carries no colour and no dash: whether a connector is solid or dashed
/// depends on the state of the node it arrives at, which is data this file has
/// never seen (BRD-1 — the screen resolves a level, not a hue).
@immutable
final class MapEdge {
  const MapEdge({required this.from, required this.to});

  final int from;
  final int to;
}

/// The positions of a map of [nodeCount] topics across a canvas [width] wide.
@immutable
final class MapLayout {
  const MapLayout._({
    required this.boxes,
    required this.edges,
    required this.rowSizes,
    required this.canvasSize,
  });

  factory MapLayout.of({
    required int nodeCount,
    required double width,
    required int? focusIndex,
  }) {
    if (nodeCount <= 0) {
      return const MapLayout._(
        boxes: <Rect>[],
        edges: <MapEdge>[],
        rowSizes: <int>[],
        canvasSize: Size.zero,
      );
    }

    final List<int> rows = _rowSizes(nodeCount);
    final List<Rect> boxes = <Rect>[];
    double centerY = 0;
    int first = 0;

    for (int row = 0; row < rows.length; row++) {
      final List<double> widths = <double>[
        for (int seat = 0; seat < rows[row]; seat++)
          _widthOf(first + seat, focusIndex),
      ];
      final double halfHeight = _heightOf(
            widths.reduce((double a, double b) => a > b ? a : b),
          ) /
          2;
      centerY += row == 0 ? topInset + halfHeight : rowPitch;

      for (int seat = 0; seat < widths.length; seat++) {
        boxes.add(
          _box(
            centerX: _centerX(
              width: width,
              seat: seat,
              seats: widths.length,
              widest: widths.reduce((double a, double b) => a > b ? a : b),
            ),
            centerY: centerY,
            width: widths[seat],
          ),
        );
      }
      first += rows[row];
    }

    return MapLayout._(
      boxes: List<Rect>.unmodifiable(boxes),
      edges: _edges(rows),
      rowSizes: List<int>.unmodifiable(rows),
      canvasSize: Size(
        width,
        boxes
                .map((Rect box) => box.bottom)
                .reduce((double a, double b) => a > b ? a : b) +
            shadowReserve,
      ),
    );
  }

  /// The paint box of each node, in node order. The hard shadow falls outside
  /// it, which is what [shadowReserve] keeps room for.
  final List<Rect> boxes;

  final List<MapEdge> edges;

  /// How many nodes each row holds. Reported so a caller — and a test — can see
  /// the pattern rather than infer it from coordinates.
  final List<int> rowSizes;

  final Size canvasSize;

  /// `05 Mapa de habilidades` draws its standard node 100 × 62.
  static const double nodeWidth = 100;

  /// The node the player is standing on, drawn 132 × 78 by the design.
  static const double focusWidth = 132;

  /// How far a paired node sits from the row's centre line: the design's own
  /// 179 − 64. Reduced when the canvas cannot hold it, never exceeded.
  static const double pairOffset = 115;

  /// The gap the design leaves between a node and the edge of the graph.
  static const double edgeInset = 14;

  /// Centre to centre between two rows.
  ///
  /// The design's rows step 98 apart five times and 92 once, squeezing the last
  /// row into a fixed 576. One pitch and a canvas that grows to fit is one
  /// number instead of a special case.
  static const double rowPitch = 98;

  /// The design's 6 px above the first row.
  static const double topInset = 6;

  /// Room below the last row for the hard shadow to fall into.
  ///
  /// Read off `BrandShape` rather than typed, so the day a shadow moves this
  /// follows it (BRD-2c).
  static final double shadowReserve = BrandShape.shadowButton.dy;

  /// A node's height, in the design's proportion to its width.
  ///
  /// 100 × 62 and 132 × 78 are the two boxes drawn, and both round to the same
  /// ratio — so one ratio reproduces both and a third size cannot arrive with
  /// a height nobody chose.
  static double _heightOf(double width) => width == focusWidth ? 78 : 62;

  static double _widthOf(int index, int? focusIndex) =>
      index == focusIndex ? focusWidth : nodeWidth;

  static Rect _box({
    required double centerX,
    required double centerY,
    required double width,
  }) {
    final double height = _heightOf(width);
    return Rect.fromLTWH(
      centerX - width / 2,
      centerY - height / 2,
      width,
      height,
    );
  }

  /// Where a seat sits across the row.
  ///
  /// A single node takes the centre line. A pair steps out from it by
  /// [pairOffset], pulled in when the widest node in the row would otherwise
  /// cross [edgeInset] — which is what keeps a hero in a pair row on screen
  /// instead of off the side of it.
  static double _centerX({
    required double width,
    required int seat,
    required int seats,
    required double widest,
  }) {
    final double middle = width / 2;
    if (seats == 1) {
      return middle;
    }
    final double room = middle - widest / 2 - edgeInset;
    final double offset = room < pairOffset ? room : pairOffset;
    final double span = 2 * offset / (seats - 1);
    return middle - offset + seat * span;
  }

  /// The design's row pattern, repeated until every node has a seat.
  static List<int> _rowSizes(int nodeCount) {
    const List<int> pattern = <int>[2, 1, 1, 2, 1, 2];
    final List<int> rows = <int>[];
    int placed = 0;
    while (placed < nodeCount) {
      final int wanted = pattern[rows.length % pattern.length];
      final int remaining = nodeCount - placed;
      rows.add(wanted < remaining ? wanted : remaining);
      placed += rows.last;
    }
    return rows;
  }

  /// Every node of a row joined to every node of the next.
  static List<MapEdge> _edges(List<int> rows) {
    final List<MapEdge> edges = <MapEdge>[];
    int first = 0;
    for (int row = 0; row + 1 < rows.length; row++) {
      final int nextFirst = first + rows[row];
      for (int from = first; from < nextFirst; from++) {
        for (int to = nextFirst; to < nextFirst + rows[row + 1]; to++) {
          edges.add(MapEdge(from: from, to: to));
        }
      }
      first = nextFirst;
    }
    return List<MapEdge>.unmodifiable(edges);
  }
}
