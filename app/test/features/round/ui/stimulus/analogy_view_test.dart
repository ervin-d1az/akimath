import 'package:akimath_app/design/widgets/candy_surface.dart';
import 'package:akimath_app/features/round/ui/stimulus/analogy_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The frozen golden: `2 › 4 como 5 › 10`, with the last term hidden.
const List<int> _doubling = <int>[2, 4, 5, 10];

Future<void> _pump(
  WidgetTester tester, {
  List<int> terms = _doubling,
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
            child: AnalogyView(terms: terms, unknownIndex: unknownIndex),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('an analogy draws four terms and a bridge', () {
    testWidgets('three values, one hole, one bridge',
        (WidgetTester tester) async {
      await _pump(tester, unknownIndex: 3);

      expect(find.text('2'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
      expect(
        find.text(AnalogyView.bridgeLabel.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('the hidden term is never drawn', (WidgetTester tester) async {
      await _pump(tester, unknownIndex: 3);

      expect(find.text('10'), findsNothing);
    });

    testWidgets('the hole can sit in the first pair too',
        (WidgetTester tester) async {
      // `unknown_index` walks all four terms, so hiding one of the *first*
      // pair's is a legal payload and a genuinely different question: it asks
      // the learner to run the rule backwards from the pair that is intact.
      // A renderer that assumed the hole was always last would draw the answer.
      await _pump(tester, unknownIndex: 1);

      expect(find.text('4'), findsNothing);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('the bridge separates the two pairs', () {
    testWidgets('two terms fall each side of it', (WidgetTester tester) async {
      // The layout claim that matters: a reader has to see two statements, not
      // four loose numbers. Without this, the bridge could render anywhere in
      // the row and every count above would still pass.
      await _pump(tester, unknownIndex: 3);

      final double bridge =
          tester.getCenter(find.text(AnalogyView.bridgeLabel.toUpperCase())).dx;

      expect(tester.getCenter(find.text('2')).dx, lessThan(bridge));
      expect(tester.getCenter(find.text('4')).dx, lessThan(bridge));
      expect(tester.getCenter(find.text('5')).dx, greaterThan(bridge));
      expect(tester.getCenter(find.text('?')).dx, greaterThan(bridge));
    });
  });

  group('the hole is distinguishable without hue', () {
    testWidgets('exactly one tile is dashed', (WidgetTester tester) async {
      await _pump(tester, unknownIndex: 2);

      // The bridge is a `StatPill`, not a `CandySurface`, so the four tiles are
      // the only ones counted here.
      final List<CandySurface> tiles =
          tester.widgetList<CandySurface>(find.byType(CandySurface)).toList();
      final Iterable<CandySurface> dashed =
          tiles.where((CandySurface t) => t.borderDash != null);

      expect(tiles, hasLength(4));
      expect(dashed, hasLength(1));
      expect(dashed.single.background, isNot(tiles.first.background));
    });
  });

  group('it survives real content', () {
    testWidgets('three-digit terms still fit 390', (WidgetTester tester) async {
      await _pump(tester, terms: <int>[100, 300, 250, 750], unknownIndex: 3);

      expect(tester.takeException(), isNull);
      expect(find.text('250'), findsOneWidget);
    });
  });
}
