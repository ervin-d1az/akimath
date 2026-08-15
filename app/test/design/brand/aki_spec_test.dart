import 'dart:ui';

import 'package:akimath_app/design/brand/spec/aki_spec.dart';
import 'package:akimath_app/design/brand/spec/brand_shapes.dart';
import 'package:akimath_app/design/tokens/brand_colors.dart';
import 'package:flutter_test/flutter_test.dart';

/// These run without a canvas, without a widget tree, and without mocks,
/// because the spec layer is data. They protect what the character means, not
/// just what it looks like.
void main() {
  group('the tail is the thing that can be lost', () {
    /// The outer pass of the tail: the widest stroke in the drawing.
    InkStroke tailOf(AkiPose pose) => AkiSpec.body(pose)
        .marks
        .whereType<InkStroke>()
        .firstWhere((InkStroke s) => s.width == 21);

    test('curls back on itself when nothing has gone wrong', () {
      for (final AkiPose pose in <AkiPose>[AkiPose.base, AkiPose.correct]) {
        final InkStroke tail = tailOf(pose);
        expect(
          (tail.end - tail.start).distance,
          lessThan(30),
          reason: '$pose should end near where it started — that is a curl.',
        );
      }
    });

    test('runs straight out when it comes undone', () {
      final InkStroke tail = tailOf(AkiPose.slip);
      expect(
        (tail.end - tail.start).distance,
        greaterThan(50),
        reason: 'The slip pose is the uncoiled tail. If it still curls, the '
            'one gesture the character exists for has been lost.',
      );
    });

    test('is drawn in ink and filled with her coat', () {
      for (final AkiPose pose in AkiPose.values) {
        final InkStroke tail = tailOf(pose);
        expect(tail.color, BrandColors.ink);
        expect(tail.coreColor, BrandColors.akiCoat);
        expect(tail.coreWidth, lessThan(tail.width));
      }
    });
  });

  group('green belongs to the regrowing curl alone', () {
    Iterable<Color> greensIn(AkiPose pose) {
      final List<BrandMark> marks = AkiSpec.body(pose).marks;
      return <Color>[
        ...marks
            .whereType<InkStroke>()
            .map((InkStroke s) => s.coreColor)
            .whereType<Color>(),
        ...marks.whereType<InkDot>().map((InkDot d) => d.fill),
        ...marks.whereType<InkShape>().map((InkShape s) => s.fill),
      ].where((Color c) => c == BrandColors.green);
    }

    test('appears only in the slip pose', () {
      expect(greensIn(AkiPose.base), isEmpty);
      expect(greensIn(AkiPose.correct), isEmpty);
      expect(greensIn(AkiPose.slip), isNotEmpty);
    });

    test('is one new curl plus its dust, and nothing else', () {
      final List<BrandMark> marks = AkiSpec.body(AkiPose.slip).marks;

      final Iterable<InkStroke> curls = marks
          .whereType<InkStroke>()
          .where((InkStroke s) => s.coreColor == BrandColors.green);
      final Iterable<InkDot> dust = marks
          .whereType<InkDot>()
          .where((InkDot d) => d.fill == BrandColors.green);

      expect(curls, hasLength(1));
      expect(dust, hasLength(2));
      expect(
        dust.every((InkDot d) => d.opacity < 1),
        isTrue,
        reason: 'Dust is fading, not solid.',
      );
    });

    test('never uses coral, which belongs to the app and not to her', () {
      for (final AkiPose pose in AkiPose.values) {
        final Iterable<Color> fills = AkiSpec.body(pose)
            .marks
            .whereType<InkDot>()
            .map((InkDot d) => d.fill);
        expect(fills, isNot(contains(BrandColors.coral)));
      }
    });
  });

  group('the face', () {
    test('paints the head over the ears', () {
      final List<BrandMark> marks = AkiSpec.face.marks;
      final int lastEar = marks.lastIndexWhere((BrandMark m) => m is InkShape);
      final int head = marks.indexWhere((BrandMark m) => m is InkOval);

      expect(lastEar, isNonNegative);
      expect(head, greaterThan(lastEar));
    });

    test('has two eyes, each with a catchlight painted on top of it', () {
      final List<InkDot> dots = AkiSpec.face.marks.whereType<InkDot>().toList();
      final List<InkDot> eyes =
          dots.where((InkDot d) => d.fill == BrandColors.ink).toList();
      final List<InkDot> lights =
          dots.where((InkDot d) => d.fill == BrandColors.surface).toList();

      expect(eyes, hasLength(2));
      expect(lights, hasLength(2));

      for (final InkDot light in lights) {
        expect(dots.indexOf(light), greaterThan(dots.indexOf(eyes.first)));
        expect(light.radius, lessThan(eyes.first.radius));
      }
    });

    test('cuts the mouth into the muzzle in coat color, never in ink', () {
      final InkStroke mouth = AkiSpec.face.marks
          .whereType<InkStroke>()
          .firstWhere((InkStroke s) => s.color == BrandColors.akiCoat);

      expect(mouth.hasCore, isFalse);
      expect(
        AkiSpec.face.marks.whereType<InkRect>().single.fill,
        BrandColors.akiMuzzle,
        reason: 'A coat-colored mouth only reads against the dark muzzle.',
      );
    });

    test('stays inside its own view box', () {
      for (final InkDot dot in AkiSpec.face.marks.whereType<InkDot>()) {
        expect(AkiSpec.faceViewBox.contains(dot.center), isTrue);
      }
    });
  });

  group('poses', () {
    test('only the correct pose carries motion ticks', () {
      int ticks(AkiPose pose) => AkiSpec.body(pose)
          .marks
          .whereType<InkStroke>()
          .where((InkStroke s) =>
              s.width == 4 &&
              !s.hasCore &&
              s.color == BrandColors.ink &&
              s.steps.single is LineTo)
          .length;

      // Four whiskers everywhere; the correct pose adds two wag ticks.
      expect(ticks(AkiPose.base), 4);
      expect(ticks(AkiPose.slip), 4);
      expect(ticks(AkiPose.correct), 6);
    });

    test('wears the collar in brand pink with a softer tag', () {
      for (final AkiPose pose in AkiPose.values) {
        final List<BrandMark> marks = AkiSpec.body(pose).marks;
        final Iterable<InkRect> collar = marks
            .whereType<InkRect>()
            .where((InkRect r) => r.fill == BrandColors.pink);
        final Iterable<InkShape> facets = marks
            .whereType<InkShape>()
            .where((InkShape s) => s.fill == BrandColors.pinkSoft);

        expect(collar, hasLength(1));
        expect(facets, hasLength(2));
      }
    });

    test('is built once and handed out by identity', () {
      for (final AkiPose pose in AkiPose.values) {
        expect(identical(AkiSpec.body(pose), AkiSpec.body(pose)), isTrue);
      }
      expect(identical(AkiSpec.face, AkiSpec.face), isTrue);
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
        width: 4,
      );

      expect(stroke.end, const Offset(20, 10));
      expect(stroke.hasCore, isFalse);
      expect(stroke.color, BrandColors.ink);
    });

    test('a core needs both a color and a width', () {
      expect(
        () => InkStroke(
          start: Offset.zero,
          steps: const <PathStep>[LineTo(Offset(1, 1))],
          width: 4,
          coreColor: BrandColors.green,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
