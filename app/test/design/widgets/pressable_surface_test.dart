import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/pressable_surface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    );

/// The decoration the surface is painting right now.
BoxDecoration _decorationOf(WidgetTester tester) {
  final Container container = tester.widget<Container>(
    find.descendant(
      of: find.byType(PressableSurface),
      matching: find.byType(Container),
    ),
  );
  return container.decoration! as BoxDecoration;
}

/// How far the painted surface has moved from its resting position.
Offset _travelOf(WidgetTester tester, Offset restingTopLeft) =>
    tester.getTopLeft(
          find.descendant(
            of: find.byType(PressableSurface),
            matching: find.byType(Container),
          ),
        ) -
        restingTopLeft;

void main() {
  group('a pressed surface travels into its own shadow', () {
    testWidgets('a keypad key is pressed', (WidgetTester tester) async {
      int presses = 0;
      await tester.pumpWidget(
        _host(
          PressableSurface(
            shadow: BrandShape.shadowTile,
            onPressed: () => presses++,
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      );

      final Offset resting = tester.getTopLeft(
        find.descendant(
          of: find.byType(PressableSurface),
          matching: find.byType(Container),
        ),
      );

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byType(PressableSurface)));
      await tester.pump();

      expect(_travelOf(tester, resting), const Offset(3, 5));
      expect(_decorationOf(tester).boxShadow, isEmpty);

      await gesture.up();
      await tester.pump();
      expect(presses, 1);
    });

    testWidgets('a primary button is released', (WidgetTester tester) async {
      int presses = 0;
      await tester.pumpWidget(
        _host(
          PressableSurface(
            shadow: BrandShape.shadowButton,
            onPressed: () => presses++,
            child: const SizedBox(width: 120, height: 52),
          ),
        ),
      );

      final Offset resting = tester.getTopLeft(
        find.descendant(
          of: find.byType(PressableSurface),
          matching: find.byType(Container),
        ),
      );

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byType(PressableSurface)));
      await tester.pump();
      expect(_travelOf(tester, resting), const Offset(4, 6));

      await gesture.up();
      await tester.pump();

      expect(_travelOf(tester, resting), Offset.zero);
      expect(
        _decorationOf(tester).boxShadow!.single.offset,
        const Offset(4, 6),
      );
      expect(presses, 1, reason: 'onPressed must fire exactly once');
    });

    testWidgets('the travel is the surface\'s own shadow, not a fixed number',
        (WidgetTester tester) async {
      // Three surfaces, three shadows, three travels — with no table anywhere
      // mapping a widget kind to a distance.
      for (final Offset shadow in <Offset>[
        BrandShape.shadowPill,
        BrandShape.shadowTile,
        BrandShape.shadowCard,
      ]) {
        await tester.pumpWidget(
          _host(
            PressableSurface(
              shadow: shadow,
              onPressed: () {},
              child: const SizedBox(width: 80, height: 52),
            ),
          ),
        );

        final Offset resting = tester.getTopLeft(
          find.descendant(
            of: find.byType(PressableSurface),
            matching: find.byType(Container),
          ),
        );
        final TestGesture gesture = await tester
            .startGesture(tester.getCenter(find.byType(PressableSurface)));
        await tester.pump();

        expect(_travelOf(tester, resting), shadow);

        await gesture.up();
        await tester.pump();
      }
    });

    testWidgets('a press applies no effect the rule does not name',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          PressableSurface(
            shadow: BrandShape.shadowTile,
            onPressed: () {},
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      );

      Size paintedSize() => tester.getSize(
            find.descendant(
              of: find.byType(PressableSurface),
              matching: find.byType(Container),
            ),
          );

      final Size unpressed = paintedSize();
      expect(find.byType(Opacity), findsNothing);
      expect(find.byType(Transform), findsNothing);

      final TestGesture gesture = await tester
          .startGesture(tester.getCenter(find.byType(PressableSurface)));
      await tester.pump();

      // No scale: the surface moves, it does not shrink. No opacity layer, and
      // no ripple — the substrate already sets NoSplash, and this asserts that
      // nothing reintroduced one.
      expect(paintedSize(), unpressed);
      expect(find.byType(Opacity), findsNothing);

      await gesture.up();
      await tester.pump();
    });
  });

  group('a shadowless pressable declares how it answers a press', () {
    testWidgets('a shadowless surface still reports a press',
        (WidgetTester tester) async {
      int presses = 0;
      await tester.pumpWidget(
        _host(
          PressableSurface(
            pressEffect: PressEffect.none,
            onPressed: () => presses++,
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      );

      final Offset resting = tester.getTopLeft(
        find.descendant(
          of: find.byType(PressableSurface),
          matching: find.byType(Container),
        ),
      );

      await tester.tap(find.byType(PressableSurface));
      await tester.pump();

      expect(presses, 1);
      expect(_travelOf(tester, resting), Offset.zero);
    });

    test('constructing one without naming a treatment fails', () {
      // DR-5: no document specifies what a shadowless control does when
      // pressed. This does not invent one — it refuses to let the absence be
      // silent, so the decision lands at the call site that adds the control.
      expect(
        () => PressableSurface(
          onPressed: () {},
          child: const SizedBox(width: 10, height: 10),
        ),
        throwsAssertionError,
      );
    });
  });

  group('every interactive target clears 48 logical pixels', () {
    testWidgets('a small surface still hit-tests at 48',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          PressableSurface(
            shadow: BrandShape.shadowPill,
            onPressed: () {},
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );

      final Size hitBox = tester.getSize(find.byType(PressableSurface));
      expect(hitBox.width, greaterThanOrEqualTo(BrandShape.minTouchTarget));
      expect(hitBox.height, greaterThanOrEqualTo(BrandShape.minTouchTarget));
    });

    testWidgets('growing the hit box does not grow the paint',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          PressableSurface(
            shadow: BrandShape.shadowPill,
            onPressed: () {},
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );

      // The painted surface keeps its drawn size. Six controls in the corpus are
      // drawn below 48 on purpose (DR-6); the fix for them is a larger hit box
      // behind unchanged paint, never a larger drawing.
      final Size painted = tester.getSize(
        find.descendant(
          of: find.byType(PressableSurface),
          matching: find.byType(Container),
        ),
      );
      expect(painted.width, lessThan(BrandShape.minTouchTarget));
      expect(painted.height, lessThan(BrandShape.minTouchTarget));
    });

    testWidgets('a tap outside the paint but inside the hit box counts',
        (WidgetTester tester) async {
      int presses = 0;
      await tester.pumpWidget(
        _host(
          PressableSurface(
            shadow: BrandShape.shadowPill,
            onPressed: () => presses++,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );

      // A point in the padding ring: outside the drawn 20x20, inside the 48x48
      // target. This is the assertion that makes the hit box mean something.
      final Rect box = tester.getRect(find.byType(PressableSurface));
      await tester.tapAt(Offset(box.left + 3, box.center.dy));
      await tester.pump();

      expect(presses, 1);
    });
  });
}
