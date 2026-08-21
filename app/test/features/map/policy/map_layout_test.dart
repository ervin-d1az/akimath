import 'dart:ui' show Rect, Size;

import 'package:akimath_app/features/map/policy/map_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// The width the design draws the graph at: 390 minus its 16 px side margins.
const double _designWidth = 358;

void main() {
  group('the rows', () {
    test('an empty map lays out nothing and takes no room', () {
      final MapLayout layout =
          MapLayout.of(nodeCount: 0, width: _designWidth, focusIndex: null);

      expect(layout.boxes, isEmpty);
      expect(layout.edges, isEmpty);
      expect(layout.canvasSize, Size.zero);
    });

    test('six nodes land on the design\'s own first four rows', () {
      // Read off `05 Mapa de habilidades`: two nodes at left 14 and 244 top 6,
      // one at 129/104, one at 129/202, then two at 14/300 and 244/300.
      final MapLayout layout =
          MapLayout.of(nodeCount: 6, width: _designWidth, focusIndex: null);

      expect(layout.boxes, <Rect>[
        const Rect.fromLTWH(14, 6, 100, 62),
        const Rect.fromLTWH(244, 6, 100, 62),
        const Rect.fromLTWH(129, 104, 100, 62),
        const Rect.fromLTWH(129, 202, 100, 62),
        const Rect.fromLTWH(14, 300, 100, 62),
        const Rect.fromLTWH(244, 300, 100, 62),
      ]);
    });

    test('nine nodes use the whole pattern the design draws', () {
      final MapLayout layout =
          MapLayout.of(nodeCount: 9, width: _designWidth, focusIndex: null);

      expect(layout.rowSizes, <int>[2, 1, 1, 2, 1, 2]);
    });

    test('a tenth node starts the pattern again rather than falling off', () {
      final MapLayout layout =
          MapLayout.of(nodeCount: 10, width: _designWidth, focusIndex: null);

      expect(layout.rowSizes, <int>[2, 1, 1, 2, 1, 2, 1]);
      expect(layout.boxes, hasLength(10));
    });
  });

  group('the node the player is standing on', () {
    test('is drawn on the design\'s larger hero box, centred where it was', () {
      final MapLayout layout =
          MapLayout.of(nodeCount: 6, width: _designWidth, focusIndex: 3);

      // 113/194/132/78 in the design, and its centre is the same 179/233 the
      // standard node would have had.
      expect(layout.boxes[3], const Rect.fromLTWH(113, 194, 132, 78));
      expect(layout.boxes[3].center, const Rect.fromLTWH(129, 202, 100, 62).center);
    });

    test('a hero in a pair row still clears the edge inset', () {
      final MapLayout layout =
          MapLayout.of(nodeCount: 6, width: _designWidth, focusIndex: 0);

      expect(layout.boxes[0].left, 14);
      expect(layout.boxes[0].width, 132);
    });
  });

  group('the connectors', () {
    test('join every node of a row to every node of the next', () {
      final MapLayout layout =
          MapLayout.of(nodeCount: 6, width: _designWidth, focusIndex: null);

      expect(
        layout.edges.map((MapEdge edge) => '${edge.from}-${edge.to}'),
        <String>['0-2', '1-2', '2-3', '3-4', '3-5'],
      );
    });

    test('one node on its own has nothing to join', () {
      final MapLayout layout =
          MapLayout.of(nodeCount: 1, width: _designWidth, focusIndex: null);

      expect(layout.edges, isEmpty);
      expect(layout.boxes, hasLength(1));
    });
  });

  group('the canvas', () {
    test('reserves the hard shadow, so a stack cannot clip it', () {
      final MapLayout layout =
          MapLayout.of(nodeCount: 6, width: _designWidth, focusIndex: null);

      expect(layout.canvasSize.width, _designWidth);
      expect(layout.canvasSize.height, 300 + 62 + MapLayout.shadowReserve);
    });
  });

  group('a canvas narrower than the design', () {
    test('pulls a pair in rather than letting it run off the side', () {
      final MapLayout layout =
          MapLayout.of(nodeCount: 2, width: 240, focusIndex: null);

      expect(layout.boxes.first.left, MapLayout.edgeInset);
      expect(layout.boxes.last.right, 240 - MapLayout.edgeInset);
    });

    test('never pushes a pair further apart than the design does', () {
      final MapLayout layout =
          MapLayout.of(nodeCount: 2, width: 900, focusIndex: null);

      expect(
        layout.boxes.last.center.dx - layout.boxes.first.center.dx,
        2 * MapLayout.pairOffset,
      );
    });
  });
}
