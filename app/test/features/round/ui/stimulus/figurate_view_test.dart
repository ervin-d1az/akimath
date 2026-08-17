import 'package:akimath_app/design/math/spec/figurate_layout.dart';
import 'package:akimath_app/design/widgets/candy_surface.dart';
import 'package:akimath_app/features/round/ui/stimulus/figurate_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The frozen golden: the first four triangular numbers.
const List<int> _triangular = <int>[1, 3, 6, 10];

Future<void> _pump(
  WidgetTester tester, {
  List<int> dotCounts = _triangular,
  required int unknownIndex,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: FigurateView(
              dotCounts: dotCounts,
              unknownIndex: unknownIndex,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('a figurate item draws a box per figure', () {
    testWidgets('four figures, four boxes', (WidgetTester tester) async {
      await _pump(tester, unknownIndex: 3);

      expect(find.byType(CandySurface), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the hole is a question mark, not an empty box',
        (WidgetTester tester) async {
      // A blank square beside three dotted ones reads as a figure of zero
      // rather than as the question.
      await _pump(tester, unknownIndex: 3);

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('only the figures that are given are painted',
        (WidgetTester tester) async {
      // Three painters for four boxes: the hole draws a `?` instead. A view
      // that painted the hidden figure would show the learner the answer as a
      // count of dots.
      await _pump(tester, unknownIndex: 3);

      expect(find.byType(CustomPaint).evaluate().length, greaterThan(0));
      final Iterable<CustomPaint> painted = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((CustomPaint p) => p.painter != null);

      expect(painted, hasLength(3));
    });

    testWidgets('the hole can be any figure, not only the last',
        (WidgetTester tester) async {
      for (final int index in <int>[0, 1, 2, 3]) {
        await _pump(tester, unknownIndex: index);

        expect(find.text('?'), findsOneWidget, reason: 'index $index');
        final Iterable<CustomPaint> painted = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((CustomPaint p) => p.painter != null);
        expect(painted, hasLength(3), reason: 'index $index');
      }
    });
  });

  group('the hole is distinguishable without hue', () {
    testWidgets('exactly one box is dashed', (WidgetTester tester) async {
      await _pump(tester, unknownIndex: 1);

      final List<CandySurface> boxes =
          tester.widgetList<CandySurface>(find.byType(CandySurface)).toList();
      final Iterable<CandySurface> dashed =
          boxes.where((CandySurface b) => b.borderDash != null);

      expect(boxes, hasLength(4));
      expect(dashed, hasLength(1));
      expect(dashed.single.background, isNot(boxes.first.background));
    });
  });

  group('the painter is fed by the spec, not by itself', () {
    testWidgets('each painted figure carries its own layout',
        (WidgetTester tester) async {
      // The dot counts differ per figure, so the layouts must too. One shared
      // layout would draw four identical figures and there would be no rule
      // to find — and every count assertion above would still pass.
      await _pump(tester, unknownIndex: 3);

      final List<CustomPaint> painted = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((CustomPaint p) => p.painter != null)
          .toList();
      final List<double> radii = painted
          .map((CustomPaint p) =>
              (p.painter! as FigurateDotsPainter).layout.radius)
          .toList();

      // 1, 3, 6 — strictly growing counts, so strictly shrinking radii.
      expect(radii[0], greaterThan(radii[1]));
      expect(radii[1], greaterThan(radii[2]));
      expect(radii[2], figurateLayout(6).radius);
    });
  });

  group('it survives real content', () {
    testWidgets('three squares instead of triangles still fit',
        (WidgetTester tester) async {
      await _pump(tester, dotCounts: <int>[1, 4, 9, 16], unknownIndex: 3);

      expect(tester.takeException(), isNull);
      expect(find.byType(CandySurface), findsNWidgets(4));
    });
  });
}
