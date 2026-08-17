import 'package:akimath_app/features/round/ui/stimulus/number_series_view.dart';
import 'package:akimath_app/design/widgets/candy_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, List<String> terms) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Inside a scaling `FittedBox`, which is how `RoundScreen` draws every
  // prompt — a series pumped bare wraps onto a second line and looks like two
  // series, and a test that pumps a shape the app never builds is a gate
  // checking something nobody ships.
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: NumberSeriesView(terms: terms),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('a series shows its terms and one hole', () {
    testWidgets('every term is drawn, in order', (WidgetTester tester) async {
      await _pump(tester, <String>['2', '4', '6', '8']);

      for (final String term in <String>['2', '4', '6', '8']) {
        expect(find.text(term), findsOneWidget);
      }
    });

    testWidgets('there is exactly one blank, and it comes last',
        (WidgetTester tester) async {
      await _pump(tester, <String>['2', '4', '6', '8']);

      expect(find.text('?'), findsOneWidget);
      expect(find.byType(CandySurface), findsNWidgets(5));

      final Offset lastTerm = tester.getCenter(find.text('8'));
      final Offset blank = tester.getCenter(find.text('?'));
      expect(blank.dx, greaterThan(lastTerm.dx));
    });

    testWidgets('the answer is never on screen', (WidgetTester tester) async {
      // The blank is drawn here rather than authored into the terms, so a pack
      // cannot ship the answer beside the question.
      await _pump(tester, <String>['2', '4', '6', '8']);

      expect(find.text('10'), findsNothing);
    });
  });

  group('the hole is distinguishable without hue', () {
    testWidgets('it is dashed and the given terms are not',
        (WidgetTester tester) async {
      // Deuteranopia collapses a good deal of the palette, so the outline
      // pattern has to carry the difference and the fill only reinforce it —
      // the same rule the verdict ring follows.
      await _pump(tester, <String>['2', '4', '6']);

      final List<CandySurface> tiles =
          tester.widgetList<CandySurface>(find.byType(CandySurface)).toList();

      expect(tiles, hasLength(4));
      expect(
        tiles.take(3).every((CandySurface t) => t.borderDash == null),
        isTrue,
        reason: 'a given term should be solid',
      );
      expect(tiles.last.borderDash, isNotNull, reason: 'the hole should be dashed');
    });

    testWidgets('and it is filled differently too', (WidgetTester tester) async {
      await _pump(tester, <String>['2', '4', '6']);

      final List<CandySurface> tiles =
          tester.widgetList<CandySurface>(find.byType(CandySurface)).toList();

      expect(tiles.last.background, isNot(tiles.first.background));
    });
  });

  group('it survives real content', () {
    testWidgets('a five-term series and a three-digit term both fit',
        (WidgetTester tester) async {
      await _pump(tester, <String>['1', '1', '2', '3', '5']);
      expect(tester.takeException(), isNull);

      await _pump(tester, <String>['2', '6', '18', '162']);
      expect(tester.takeException(), isNull);
      expect(find.text('162'), findsOneWidget);
    });
  });
}
