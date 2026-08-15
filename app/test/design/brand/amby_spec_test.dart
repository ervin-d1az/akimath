import 'dart:ui';

import 'package:ambysmath_app/design/brand/spec/amby_spec.dart';
import 'package:ambysmath_app/design/brand/spec/brand_shapes.dart';
import 'package:ambysmath_app/design/tokens/brand_colors.dart';
import 'package:flutter_test/flutter_test.dart';

/// These run without a canvas, without a widget tree, and without mocks,
/// because the spec layer is data. They protect the brand's geometry: an edit
/// that quietly moves a gill or drops an outline fails here, not in review.
void main() {
  group('face', () {
    final BrandDrawing face = AmbySpec.face;

    test('has six gills, each with a tip anchored at the stroke end', () {
      final List<InkStroke> strokes = face.marks.whereType<InkStroke>().toList();
      final List<InkDot> outlined =
          face.marks.whereType<InkDot>().where((InkDot d) => d.hasOutline).toList();

      // Six gill strokes plus the smile.
      expect(strokes.where((InkStroke s) => s.hasCore), hasLength(6));
      expect(outlined, hasLength(6));

      final Set<Offset> gillEnds = strokes
          .where((InkStroke s) => s.hasCore)
          .map((InkStroke s) => s.end)
          .toSet();
      expect(
        outlined.map((InkDot d) => d.center).toSet(),
        equals(gillEnds),
        reason: 'Every gill tip sits exactly where its stroke ends.',
      );
    });

    test('every gill is drawn ink-first, then a thinner pink core', () {
      final Iterable<InkStroke> gills =
          face.marks.whereType<InkStroke>().where((InkStroke s) => s.hasCore);

      for (final InkStroke gill in gills) {
        expect(gill.coreColor, BrandColors.pink);
        expect(
          gill.coreWidth,
          lessThan(gill.inkWidth),
          reason: 'The core must be narrower than the ink or no outline shows.',
        );
      }
    });

    test('paints the head after the gills so it covers their roots', () {
      final int lastGill = face.marks.lastIndexWhere(
        (BrandMark m) => m is InkStroke && m.hasCore,
      );
      final int head = face.marks.indexWhere((BrandMark m) => m is InkOval);

      expect(head, greaterThan(lastGill));
    });

    test('eyes are solid ink and cheeks are translucent pink', () {
      final List<InkDot> plain = face.marks
          .whereType<InkDot>()
          .where((InkDot d) => !d.hasOutline)
          .toList();

      final List<InkDot> eyes =
          plain.where((InkDot d) => d.fill == BrandColors.ink).toList();
      final List<InkDot> cheeks =
          plain.where((InkDot d) => d.fill == BrandColors.pink).toList();

      expect(eyes, hasLength(2));
      expect(eyes.every((InkDot d) => d.opacity == 1), isTrue);
      expect(cheeks, hasLength(2));
      expect(cheeks.every((InkDot d) => d.opacity < 1), isTrue);
    });

    test('stays inside its own view box', () {
      for (final InkDot dot in face.marks.whereType<InkDot>()) {
        expect(face.viewBox.inflate(dot.radius).contains(dot.center), isTrue);
      }
    });
  });

  group('poses', () {
    test('base and fan carry six gills; error is missing one', () {
      expect(_gillCount(AmbyPose.base), 6);
      expect(_gillCount(AmbyPose.fan), 6);
      expect(
        _gillCount(AmbyPose.error),
        5,
        reason: 'The error pose loses a gill — that is the whole tell.',
      );
    });

    test('fanned gills reach farther from the head than resting ones', () {
      const Offset head = Offset(120, 96);

      double reach(AmbyPose pose) {
        final Iterable<double> distances = _gills(pose)
            .map((InkStroke s) => (s.end - head).distance);
        return distances.reduce((double a, double b) => a > b ? a : b);
      }

      expect(
        reach(AmbyPose.fan),
        greaterThan(reach(AmbyPose.base)),
        reason: 'A fanned pose that does not fan is not a pose.',
      );
    });

    test('the error pose gets a wider box for the gill that flew off', () {
      expect(
        AmbySpec.bodyViewBox(AmbyPose.error).width,
        greaterThan(AmbySpec.bodyViewBox(AmbyPose.base).width),
      );
    });

    test('the detached gill is the only green mark on Amby', () {
      final List<BrandMark> marks = AmbySpec.body(AmbyPose.error).marks;

      final Iterable<Color> greenCores = marks
          .whereType<InkStroke>()
          .map((InkStroke s) => s.coreColor)
          .whereType<Color>()
          .where((Color c) => c == BrandColors.green);
      final Iterable<InkDot> greenDots = marks
          .whereType<InkDot>()
          .where((InkDot d) => d.fill == BrandColors.green);

      expect(greenCores, hasLength(1));
      expect(greenDots, hasLength(1));

      for (final AmbyPose pose in <AmbyPose>[AmbyPose.base, AmbyPose.fan]) {
        expect(
          AmbySpec.body(pose).marks.whereType<InkDot>().where(
                (InkDot d) => d.fill == BrandColors.green,
              ),
          isEmpty,
        );
      }
    });

    test('every pose is built once and handed out by identity', () {
      for (final AmbyPose pose in AmbyPose.values) {
        expect(identical(AmbySpec.body(pose), AmbySpec.body(pose)), isTrue);
      }
      expect(identical(AmbySpec.face, AmbySpec.face), isTrue);
    });
  });

  group('primitives', () {
    test('a stroke ends where its last step ends', () {
      const InkStroke stroke = InkStroke(
        start: Offset.zero,
        steps: <PathStep>[
          LineTo(Offset(10, 0)),
          QuadTo(Offset(15, 5), Offset(20, 10)),
        ],
        inkWidth: 4,
      );

      expect(stroke.end, const Offset(20, 10));
      expect(stroke.hasCore, isFalse);
    });

    test('a stroke with no steps ends where it started', () {
      const InkStroke stroke = InkStroke(
        start: Offset(3, 4),
        steps: <PathStep>[],
        inkWidth: 1,
      );

      expect(stroke.end, const Offset(3, 4));
    });

    test('a core needs both a color and a width', () {
      expect(
        () => InkStroke.line(
          Offset.zero,
          const Offset(1, 1),
          inkWidth: 4,
          coreColor: BrandColors.pink,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

Iterable<InkStroke> _gills(AmbyPose pose) => AmbySpec.body(pose)
    .marks
    .whereType<InkStroke>()
    .where((InkStroke s) => s.coreColor == BrandColors.pink && s.inkWidth == 15);

int _gillCount(AmbyPose pose) => _gills(pose).length;
