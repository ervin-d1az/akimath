import 'package:akimath_app/content/model/diagnosis.dart';
import 'package:akimath_app/demo/demo_figures.dart';
import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/design/widgets/baseline_meter.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/design/widgets/stat_tile.dart';
import 'package:akimath_app/design/widgets/verdict_ring.dart';
import 'package:akimath_app/features/round/ui/summary/series_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Diagnosis _stumble = Diagnosis(
  steps: <String>['Fíjate en cuánto crece la serie entre un número y el otro.'],
  explain: 'La diferencia crece; no es la misma cada vez.',
);

Future<void> _pump(
  WidgetTester tester, {
  int correct = 4,
  int total = 5,
  Duration elapsed = const Duration(seconds: 47),
  int streakDays = 3,
  List<Verdict> outcomes = const <Verdict>[
    Verdict.correct,
    Verdict.correct,
    Verdict.correct,
    Verdict.wrong,
    Verdict.correct,
  ],
  Diagnosis? stumble,
  VoidCallback? onDone,
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
          outcomes: outcomes,
          stumble: stumble,
        ),
        onDone: onDone ?? () {},
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
      .where((String text) => text != label)
      .join();
}

void main() {
  group('the ring is the series, item by item', () {
    testWidgets('one mark per answered item, in the order they were answered',
        (WidgetTester tester) async {
      await _pump(tester);

      final List<Verdict> drawn = tester
          .widgetList<VerdictRing>(find.byType(VerdictRing))
          .map((VerdictRing ring) => ring.verdict)
          .toList();

      expect(drawn, <Verdict>[
        Verdict.correct,
        Verdict.correct,
        Verdict.correct,
        Verdict.wrong,
        Verdict.correct,
      ]);
    });

    testWidgets('a different series draws a different ring',
        (WidgetTester tester) async {
      // The control: a ring built from `correct` and `total` rather than from
      // the outcomes would draw four greens and a coral whatever the order.
      await _pump(tester, correct: 1, total: 2, outcomes: <Verdict>[
        Verdict.wrong,
        Verdict.correct,
      ]);

      final List<Verdict> drawn = tester
          .widgetList<VerdictRing>(find.byType(VerdictRing))
          .map((VerdictRing ring) => ring.verdict)
          .toList();

      expect(drawn, <Verdict>[Verdict.wrong, Verdict.correct]);
    });

    testWidgets('a series left part-way draws only what was answered',
        (WidgetTester tester) async {
      await _pump(tester, correct: 2, total: 5, outcomes: <Verdict>[
        Verdict.correct,
        Verdict.correct,
      ]);

      expect(find.byType(VerdictRing), findsNWidgets(2));
    });

    testWidgets('with no outcomes at all the score is still stated',
        (WidgetTester tester) async {
      // **The unwired state, and it must not read as a clean sheet.** A caller
      // that hands over no outcomes gets the count in words instead of an empty
      // row — the ring is a richer way of saying the same thing, never the only
      // way it is said.
      await _pump(tester, outcomes: const <Verdict>[]);

      expect(find.byType(VerdictRing), findsNothing);
      expect(find.text('4 de 5'), findsOneWidget);
    });
  });

  group('the three tiles', () {
    testWidgets('rating, total time and the streak', (WidgetTester tester) async {
      await _pump(tester);

      expect(find.byType(StatTile), findsNWidgets(3));
      expect(find.text('EN TOTAL'), findsOneWidget);
      expect(_tile(tester, 'RACHA'), '3');
    });

    testWidgets('the time is the whole series and not the last item',
        (WidgetTester tester) async {
      await _pump(tester, elapsed: const Duration(milliseconds: 51400));

      // Built with the same formatter: the assertion is about *which*
      // duration reaches the tile, not about how a decimal is spelled.
      expect(
        _tile(tester, 'EN TOTAL'),
        EsMxNumber.seconds(51.4, places: 1),
      );
    });
  });

  group('the one invented figure is the rating, and it comes from DemoFigures',
      () {
    testWidgets('the tile shows exactly the quarantined constant',
        (WidgetTester tester) async {
      // **Q3/D17 kept a rating off this screen until 2026-08-20**, on the rule
      // that F2 shows no figure a later sync could contradict. The demo took an
      // openly-invented one from `DemoFigures` instead — which is a different
      // thing from computing one: `CLAUDE.md` says rating never runs in Dart,
      // and this assertion is what goes red the day something here tries.
      await _pump(tester);

      expect(DemoFigures.seriesRatingDelta, 12);
      expect(_tile(tester, 'RATING'), contains('12'));
    });

    testWidgets('it does not move with the score', (WidgetTester tester) async {
      // A rating that changed with `correct` would be a *derived* figure, which
      // is the thing that must not exist on this side. Invented is honest;
      // computed is a claim.
      await _pump(tester, correct: 0);
      final String none = _tile(tester, 'RATING');
      await _pump(tester, correct: 5);

      expect(_tile(tester, 'RATING'), none);
    });

    testWidgets('the mastery bars are the design\'s two, and invented together',
        (WidgetTester tester) async {
      await _pump(tester);

      expect(find.text('QUÉ MEJORÓ'), findsOneWidget);
      expect(find.byType(BaselineMeter), findsNWidgets(2));
      for (final DemoSkillBar bar in DemoFigures.seriesSkills) {
        expect(find.text(bar.skill), findsOneWidget);
        expect(find.text(EsMxNumber.percent(bar.percent)), findsOneWidget);
      }
    });

    testWidgets('and one recommendation, not a list', (WidgetTester tester) async {
      await _pump(tester);

      expect(find.text(DemoFigures.seriesNext), findsOneWidget);
      expect(find.text(DemoFigures.seriesNextNote), findsOneWidget);
    });
  });

  group('what went wrong is the pack\'s words or nothing at all', () {
    testWidgets('the block appears when the series carries a stumble',
        (WidgetTester tester) async {
      await _pump(tester, stumble: _stumble);

      expect(find.text('QUÉ SE TORCIÓ'), findsOneWidget);
      expect(find.text(_stumble.steps.single), findsOneWidget);
    });

    testWidgets('and is absent when nothing went wrong',
        (WidgetTester tester) async {
      // No heading over nothing — the same reading `HISTORIAL` gets on `4.1`.
      await _pump(tester, correct: 5, outcomes: const <Verdict>[
        Verdict.correct,
        Verdict.correct,
        Verdict.correct,
        Verdict.correct,
        Verdict.correct,
      ]);

      expect(find.text('QUÉ SE TORCIÓ'), findsNothing);
    });

    testWidgets('and absent when the pack declares no copy for the slip',
        (WidgetTester tester) async {
      // A slip with no words is still a slip — the ring shows it. What is
      // absent is the explanation, because there is none to give.
      await _pump(tester);

      expect(find.text('QUÉ SE TORCIÓ'), findsNothing);
      expect(find.byType(VerdictRing), findsNWidgets(5));
    });
  });

  group('one way back to the home', () {
    testWidgets('the primary button calls onDone', (WidgetTester tester) async {
      int done = 0;
      await _pump(tester, onDone: () => done++);

      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();

      expect(done, 1);
    });

    testWidgets('and nothing offers a destination that does not exist',
        (WidgetTester tester) async {
      // `2.5` draws a second button, `Ver el reto que falló`. Nothing reviews a
      // past item, so drawing it would be a control that does nothing —
      // absent rather than dead, the same rule the four missing settings rows
      // follow.
      await _pump(tester, stumble: _stumble);

      expect(find.text('Ver el reto que falló'), findsNothing);
    });
  });

  group('it never scolds, at any score', () {
    testWidgets('none of the four forbidden words, from 0 to 5',
        (WidgetTester tester) async {
      // The same sweep `verdict_screen_test.dart` runs. `req-diagnosis-copy`
      // is about the whole product, not about one screen.
      for (int correct = 0; correct <= 5; correct++) {
        await _pump(tester, correct: correct, stumble: _stumble);
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
      await _pump(tester, correct: 0);

      expect(_copy(tester), isNotEmpty);
      expect(find.byType(Aki), findsOneWidget);
    });

    testWidgets('the copy changes with the score', (WidgetTester tester) async {
      // The control: one fixed sentence would pass every assertion above.
      await _pump(tester, correct: 5);
      final String perfect = _copy(tester).join(' ');
      await _pump(tester, correct: 0);

      expect(perfect, isNot(_copy(tester).join(' ')));
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
