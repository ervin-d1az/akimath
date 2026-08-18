import 'package:akimath_app/design/widgets/baseline_meter.dart';
import 'package:akimath_app/design/widgets/spec/mastery_level.dart';
import 'package:akimath_app/design/widgets/spec/meter_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 200, child: child)),
      ),
    );

void main() {
  group('the meter is handed a level, never a colour', () {
    test('the constructor takes no parameter of type Color', () {
      // Enumerated by construction: every named parameter is listed, and a
      // Color added to the signature has to be added here too — at which point
      // the assertion below fails.
      const BaselineMeter meter = BaselineMeter(
        fill: MasteryLevel.mastered,
        fraction: 0.5,
        track: MeterTrack.inline,
        baseline: 0.25,
      );

      final List<Object?> surface = <Object?>[
        meter.fill,
        meter.fraction,
        meter.track,
        meter.baseline,
      ];
      for (final Object? value in surface) {
        expect(value, isNot(isA<Color>()));
      }
      expect(surface, hasLength(4), reason: 'the surface grew — re-check it');
    });

    testWidgets('every level resolves to a distinct fill', (WidgetTester tester) async {
      // All four arms exercised, so none is unreachable behind an enum a test
      // merely pins — the MathTone.muted failure, avoided by construction.
      final Set<Color> seen = <Color>{};
      for (final MasteryLevel level in MasteryLevel.values) {
        await _pump(
          tester,
          BaselineMeter(fill: level, fraction: 0.5),
        );
        final Container fillBox = tester.widgetList<Container>(
          find.byType(Container),
        ).elementAt(1);
        seen.add((fillBox.decoration! as BoxDecoration).color!);
      }

      expect(
        seen,
        hasLength(MasteryLevel.values.length),
        reason: 'two levels resolve to the same hue',
      );
    });
  });

  group('the geometry comes from MeterLayout', () {
    testWidgets('the meter is as tall as its marker', (WidgetTester tester) async {
      for (final MeterTrack track in <MeterTrack>[
        MeterTrack.inline,
        MeterTrack.standard,
      ]) {
        await _pump(
          tester,
          BaselineMeter(
            fill: MasteryLevel.inProgress,
            fraction: 0.5,
            track: track,
            baseline: 0.5,
          ),
        );
        expect(
          tester.getSize(find.byType(BaselineMeter)).height,
          MeterLayout.of(track).markerHeight,
        );
      }
    });

    testWidgets('the fill is a fraction of the track width',
        (WidgetTester tester) async {
      await _pump(
        tester,
        const BaselineMeter(fill: MasteryLevel.mastered, fraction: 0.25),
      );

      final Container fillBox =
          tester.widgetList<Container>(find.byType(Container)).elementAt(1);
      expect(fillBox.constraints!.maxWidth, 50);
    });

    testWidgets('a fraction beyond the track is clamped, not overflowed',
        (WidgetTester tester) async {
      // A painter's overflow is invisible to screen_overflow_test, which walks
      // the widget tree — so the clamp has to be asserted here.
      await _pump(
        tester,
        const BaselineMeter(fill: MasteryLevel.mastered, fraction: 4),
      );

      final Container fillBox =
          tester.widgetList<Container>(find.byType(Container)).elementAt(1);
      expect(fillBox.constraints!.maxWidth, 200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no marker is drawn when no baseline is given',
        (WidgetTester tester) async {
      await _pump(
        tester,
        const BaselineMeter(fill: MasteryLevel.mastered, fraction: 0.5),
      );
      expect(find.byType(ColoredBox), findsNothing);

      await _pump(
        tester,
        const BaselineMeter(
          fill: MasteryLevel.mastered,
          fraction: 0.5,
          baseline: 0.5,
        ),
      );
      expect(find.byType(ColoredBox), findsOneWidget);
    });

    testWidgets('a marker at the far end stays inside the track',
        (WidgetTester tester) async {
      await _pump(
        tester,
        const BaselineMeter(
          fill: MasteryLevel.mastered,
          fraction: 1,
          baseline: 1,
        ),
      );

      final Rect meter = tester.getRect(find.byType(BaselineMeter));
      final Rect marker = tester.getRect(find.byType(ColoredBox));
      expect(marker.right, lessThanOrEqualTo(meter.right + 0.01));
      expect(marker.left, greaterThanOrEqualTo(meter.left - 0.01));
    });
  });
}
