import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/widgets/stat_tile.dart';
import 'package:akimath_app/features/round/ui/summary/series_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  int correct = 4,
  int total = 5,
  Duration elapsed = const Duration(seconds: 47),
  int streakDays = 3,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: SeriesSummaryScreen(
        result: SeriesResult(
          correct: correct,
          total: total,
          elapsed: elapsed,
          streakDays: streakDays,
        ),
        onDone: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Iterable<String> _copy(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => s.isNotEmpty);

/// The figure inside a stat tile, found by its label.
String _tile(WidgetTester tester, String label) {
  final Finder tile = find.ancestor(
    of: find.text(label),
    matching: find.byType(StatTile),
  );
  return tester
      .widgetList<Text>(find.descendant(of: tile, matching: find.byType(Text)))
      .map((Text t) => t.data ?? '')
      .firstWhere((String text) => text != label);
}

void main() {
  group('the summary says how the series went', () {
    testWidgets('three tiles: how many, how long, the streak',
        (WidgetTester tester) async {
      await _pump(tester);

      expect(find.byType(StatTile), findsNWidgets(3));
      expect(_tile(tester, 'ACIERTOS'), '4 de 5');
      expect(find.text('TIEMPO'), findsOneWidget);
      expect(_tile(tester, 'RACHA'), '3');
    });

    testWidgets('one way back to the home', (WidgetTester tester) async {
      int done = 0;
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SeriesSummaryScreen(
            result: const SeriesResult(
              correct: 5,
              total: 5,
              elapsed: Duration(seconds: 30),
              streakDays: 1,
            ),
            onDone: () => done++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();

      expect(done, 1);
    });
  });

  group('nothing here is a figure sync could later contradict', () {
    testWidgets('no rating and no placeholder for one',
        (WidgetTester tester) async {
      // Q3/D17: the rating is the server's exclusive authority and there is no
      // server. The design draws two server-owned figures on `2.5`; a greyed-out
      // pill for either would be exactly what that decision rejected.
      for (final int correct in <int>[0, 3, 5]) {
        await _pump(tester, correct: correct);
        final String all = _copy(tester).join(' ').toLowerCase();
        for (final String forbidden in <String>['rating', 'puntos', 'nivel', 'elo']) {
          expect(all, isNot(contains(forbidden)), reason: 'with $correct correct');
        }
      }
    });

    testWidgets('exactly three tiles at every score', (WidgetTester tester) async {
      // A fourth tile is how a placeholder arrives.
      for (final int correct in <int>[0, 1, 5]) {
        await _pump(tester, correct: correct);
        expect(find.byType(StatTile), findsNWidgets(3));
      }
    });
  });

  group('it never scolds, at any score', () {
    testWidgets('none of the four forbidden words, from 0 to 5',
        (WidgetTester tester) async {
      // The same sweep `verdict_screen_test.dart` runs. `req-diagnosis-copy`
      // is about the whole product, not about one screen.
      for (int correct = 0; correct <= 5; correct++) {
        await _pump(tester, correct: correct);
        final String all = _copy(tester).join(' ').toLowerCase();
        for (final String forbidden in <String>[
          'incorrecto',
          'error',
          'fallaste',
          'mal',
        ]) {
          expect(all, isNot(contains(forbidden)), reason: '$correct de 5');
        }
      }
    });

    testWidgets('and still says something at zero', (WidgetTester tester) async {
      // A screen that passed the sweep above by rendering nothing would be
      // worse than one that scolded. Zero out of five is the case that most
      // needs a sentence.
      await _pump(tester, correct: 0);

      expect(_copy(tester), isNotEmpty);
      expect(_tile(tester, 'ACIERTOS'), '0 de 5');
      expect(find.byType(Aki), findsOneWidget);
    });

    testWidgets('the copy changes with the score', (WidgetTester tester) async {
      // The control: one fixed sentence would pass every assertion above.
      await _pump(tester, correct: 5);
      final String perfect = _copy(tester).join(' ');
      await _pump(tester, correct: 0);
      final String none = _copy(tester).join(' ');

      expect(perfect, isNot(none));
    });
  });

  group('the house rules hold here too', () {
    testWidgets('no visible timer', (WidgetTester tester) async {
      await _pump(tester);
      for (final String text in _copy(tester)) {
        expect(text, isNot(matches(RegExp(r'\d+:\d\d'))));
      }
    });
  });
}
