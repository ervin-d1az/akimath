import 'package:akimath_app/content/model/diagnosis.dart';
import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/features/round/policy/answer_draft.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/design/widgets/stat_tile.dart';
import 'package:akimath_app/design/widgets/verdict_ring.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Item> _oneItem = <Item>[
  Item(
    id: 't1',
    stimulus: ArithmeticStimulus(<PromptToken>[
      PromptToken.text('14'),
      PromptToken.operator('×'),
      PromptToken.text('3'),
      PromptToken.operator('='),
    ]),
    answer: PlainAnswer('42'),
    ladderStep: 2,
  ),
];

Future<void> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: RoundScreen(items: _oneItem)),
  );
}

/// The text currently in the answer slot.
String _answer(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey<String>('answer-draft'))).data!;

Future<void> _press(WidgetTester tester, String id) async {
  await tester.tap(
    find.byWidgetPredicate(
      (Widget w) => w is KeypadKeyView && w.data.id == id,
    ),
  );
  await tester.pump();
}

const List<Item> _twoItems = <Item>[
  Item(
    id: 't1',
    stimulus: ArithmeticStimulus(<PromptToken>[
      PromptToken.text('14'),
      PromptToken.operator('×'),
      PromptToken.text('3'),
      PromptToken.operator('='),
    ]),
    answer: PlainAnswer('42'),
    ladderStep: 2,
  ),
  Item(
    id: 't2',
    stimulus: ArithmeticStimulus(<PromptToken>[
      PromptToken.text('5'),
      PromptToken.operator('+'),
      PromptToken.text('1'),
      PromptToken.operator('='),
    ]),
    answer: PlainAnswer('6'),
    ladderStep: 1,
  ),
];

/// The figure a stat tile shows, found by its label.
String _tileFigure(WidgetTester tester, String label) {
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
  group('the time it reports is the time the player took', () {
    testWidgets('the first item is timed from when it appeared',
        (WidgetTester tester) async {
      // **`late` with an initializer runs on first *read*.** `_startedAt` is not
      // read while the item is on screen, so its first read was inside `_submit`
      // — *after* the finish instant had been captured. Every round's first item
      // therefore reported a negative duration, which is every first verdict a
      // player ever sees: the tile read `−0,0 s`. Items 2..n were right, because
      // `_next` assigns the field before the initializer can fire.
      final List<DateTime> instants = <DateTime>[
        DateTime(2026, 8, 17, 9, 0, 0),
        DateTime(2026, 8, 17, 9, 0, 7, 400),
      ];
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RoundScreen(items: _oneItem, now: () => instants.removeAt(0)),
        ),
      );

      for (final String id in <String>['4', '2', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();

      expect(instants, isEmpty, reason: 'the clock was read a different number '
          'of times than this test accounts for');
      // Built through the formatter rather than typed: the figure carries a thin
      // no-break space, and a literal here would compare invisibly-unequal.
      final String figure = _tileFigure(tester, 'TIEMPO');
      expect(figure, EsMxNumber.seconds(7.4, places: 1));
      // Guards the degenerate case: comparing two calls of the same formatter
      // would also pass if the formatter returned nothing.
      expect(figure, isNotEmpty);
      expect(figure, isNot(startsWith('−')), reason: 'a negative duration');
    });

    testWidgets('the second item is timed from when it appeared, not the first',
        (WidgetTester tester) async {
      // The control: the fix must not make every item share one start.
      final List<DateTime> instants = <DateTime>[
        DateTime(2026, 8, 17, 9, 0, 0), // item 1 shown
        DateTime(2026, 8, 17, 9, 0, 3), // item 1 submitted
        DateTime(2026, 8, 17, 9, 0, 30), // item 2 shown
        DateTime(2026, 8, 17, 9, 0, 32), // item 2 submitted
      ];
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RoundScreen(items: _twoItems, now: () => instants.removeAt(0)),
        ),
      );

      for (final String id in <String>['4', '2', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();
      expect(_tileFigure(tester, 'TIEMPO'), EsMxNumber.seconds(3, places: 1));

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      for (final String id in <String>['6', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();

      expect(_tileFigure(tester, 'TIEMPO'), EsMxNumber.seconds(2, places: 1));
      expect(instants, isEmpty);
    });
  });

  group('a series ends when it has an ending, and cycles when it does not', () {
    testWidgets('onFinished fires on the last item and not before',
        (WidgetTester tester) async {
      // **The guard, asserted.** Every other test here passes one item, so
      // `_index == items.length - 1` was never exercised: rewriting the body as
      // `if (finished != null)` left the whole suite green while a real series
      // would have ended after its first item.
      int finished = 0;
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RoundScreen(items: _twoItems, onFinished: (_) => finished++),
        ),
      );

      await _press(tester, '4');
      await _press(tester, '2');
      await _press(tester, 'submit');
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(finished, 0, reason: 'the series ended on its first item');
      expect(find.text('Reto 2'), findsOneWidget);

      await _press(tester, '6');
      await _press(tester, 'submit');
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(finished, 1);
    });

    testWidgets('a wrong last answer ends a multi-item series, not a one-item one',
        (WidgetTester tester) async {
      // **The asymmetry, and it is the whole point of the rule.** On a one-item
      // round the only "another one" `Intentar otro` can offer is *this* one, so
      // a wrong verdict must not end it. With more items the button offers a
      // genuinely different item, and the last item ends the round either way —
      // otherwise a series a player keeps failing wraps to item 1 forever and
      // `onFinished` never fires.
      int finished = 0;
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RoundScreen(items: _twoItems, onFinished: (_) => finished++),
        ),
      );

      for (final String id in <String>['4', '2', 'submit']) {
        await _press(tester, id);
      }
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Reto 2'), findsOneWidget);

      // Wrong on the last item.
      for (final String id in <String>['9', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Intentar otro'));
      await tester.pumpAndSettle();

      expect(finished, 1, reason: 'the series wrapped back to its first item');
      expect(find.text('Reto 1'), findsNothing);
    });

    testWidgets('without onFinished the last item cycles back to the first',
        (WidgetTester tester) async {
      // The control: a practice series is endless, and this change must not have
      // quietly ended it.
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: RoundScreen(items: _twoItems)),
      );

      for (final String id in <String>['4', '2', 'submit']) {
        await _press(tester, id);
      }
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      for (final String id in <String>['6', 'submit']) {
        await _press(tester, id);
      }
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Reto 1'), findsOneWidget);
    });

    testWidgets('a skip control appears only when there is another item',
        (WidgetTester tester) async {
      // One item has nowhere to skip to, and the control routed to `_next` —
      // which on the last item calls `onFinished`. On the one-item tutorial that
      // completed the first run with nothing solved.
      await _pump(tester);
      expect(find.text('Saltar este reto'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(home: RoundScreen(items: _twoItems)),
      );
      expect(find.text('Saltar este reto'), findsOneWidget);

      await tester.tap(find.text('Saltar este reto'));
      await tester.pumpAndSettle();
      expect(find.text('Reto 2'), findsOneWidget);
    });
  });

  group('a player can answer an item', () {
    testWidgets('typing shows the answer and no verdict yet',
        (WidgetTester tester) async {
      await _pump(tester);
      await _press(tester, '4');
      await _press(tester, '2');

      expect(_answer(tester), '42');
      expect(
        find.byType(VerdictRing),
        findsNothing,
        reason: 'a verdict appeared before the answer was submitted',
      );
    });

    testWidgets('a right answer shows the correct verdict',
        (WidgetTester tester) async {
      await _pump(tester);
      await _press(tester, '4');
      await _press(tester, '2');
      await _press(tester, 'submit');

      expect(
        tester.widget<VerdictRing>(find.byType(VerdictRing)).verdict,
        Verdict.correct,
      );
    });

    testWidgets('a wrong answer shows the wrong verdict',
        (WidgetTester tester) async {
      await _pump(tester);
      await _press(tester, '9');
      await _press(tester, 'submit');

      expect(
        tester.widget<VerdictRing>(find.byType(VerdictRing)).verdict,
        Verdict.wrong,
      );
    });

    testWidgets('backspace removes a digit', (WidgetTester tester) async {
      await _pump(tester);
      await _press(tester, '4');
      await _press(tester, '2');
      await _press(tester, 'backspace');

      expect(_answer(tester), '4');
    });

    testWidgets('an empty answer cannot be submitted',
        (WidgetTester tester) async {
      await _pump(tester);
      await _press(tester, 'submit');

      expect(
        find.byType(VerdictRing),
        findsNothing,
        reason: 'an empty answer was judged',
      );
    });

    testWidgets('continuing from the verdict returns an empty draft',
        (WidgetTester tester) async {
      await _pump(tester);
      await _press(tester, '4');
      await _press(tester, '2');
      await _press(tester, 'submit');

      // A verdict is its own screen now, so the keypad is not on it — a player
      // reaching for the pad after a result cannot seed the next answer with
      // whatever they happen to hit, because there is nothing to hit.
      expect(find.byType(VerdictRing), findsOneWidget);
      expect(find.byType(Keypad), findsNothing);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.byType(VerdictRing), findsNothing);
      expect(_answer(tester).trim(), isEmpty, reason: 'the draft did not reset');
    });
  });

  group('the round obeys the house rules', () {
    testWidgets('there is no visible timer', (WidgetTester tester) async {
      await _pump(tester);

      // CLAUDE.md: no visible timer, ever. Time is measured quietly.
      for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(matches(RegExp(r'\d+:\d\d'))));
      }
    });

    testWidgets('the system keyboard never appears',
        (WidgetTester tester) async {
      await _pump(tester);
      expect(find.byType(EditableText), findsNothing);
    });
  });

  group('what is shown is what is graded', () {
    testWidgets('a full-length answer is displayed in full',
        (WidgetTester tester) async {
      // The slot is 140px and a Darumadrop `0` advances ~27px at 40px, so it
      // held five or six digits while AnswerDraft.maxLength permits twelve.
      // Clipped, the answer shown and the answer graded differed — and
      // backspacing a hidden character looked like a keypress that did nothing.
      await _pump(tester);
      for (int i = 0; i < AnswerDraft.maxLength; i++) {
        await _press(tester, '8');
      }

      expect(_answer(tester), '8' * AnswerDraft.maxLength);

      final Finder answer = find.byKey(const ValueKey<String>('answer-draft'));
      final Rect slot = tester.getRect(
        find.ancestor(of: answer, matching: find.byType(FittedBox)),
      );
      final Rect text = tester.getRect(answer);

      // **Both corners, on real rects.** The first version of this assertion
      // read `text.width * (slot.width / text.width) <= slot.width + 0.5`,
      // which reduces to `slot.width <= slot.width + 0.5` — true of any widget
      // tree, and so no test at all. It was written to hold down a *painting*
      // defect and held down nothing.
      //
      // Checking only the top-left would repeat last round's miss: an overflow
      // on the right can never violate it.
      expect(
        slot.inflate(1).contains(text.topLeft),
        isTrue,
        reason: 'the answer starts outside its slot',
      );
      expect(
        slot.inflate(1).contains(text.bottomRight),
        isTrue,
        reason: 'the answer overflows its slot: $text against $slot',
      );
    });

    testWidgets('backspace always changes what is on screen',
        (WidgetTester tester) async {
      await _pump(tester);
      for (int i = 0; i < AnswerDraft.maxLength; i++) {
        await _press(tester, '8');
      }

      final String before = _answer(tester);
      await _press(tester, 'backspace');

      expect(
        _answer(tester),
        isNot(before),
        reason: 'a keypress that visibly did nothing',
      );
      expect(_answer(tester).length, before.length - 1);
    });
  });

  group('a finished series reports what happened, item by item', () {
    testWidgets('the outcomes come back in the order they were answered',
        (WidgetTester tester) async {
      // **A count cannot draw the ring.** `2.5` shows one mark per item in
      // series order, and `correct: 1, total: 2` cannot say which one was
      // missed — the round is the only thing that knows, because it graded
      // them.
      RoundOutcome? outcome;
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RoundScreen(
            items: _twoItems,
            onFinished: (RoundOutcome result) => outcome = result,
          ),
        ),
      );

      // Right on the first item, wrong on the second.
      for (final String id in <String>['4', '2', 'submit']) {
        await _press(tester, id);
      }
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      for (final String id in <String>['9', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Intentar otro'));
      await tester.pumpAndSettle();

      expect(outcome!.outcomes, <Verdict>[Verdict.correct, Verdict.wrong]);
      expect(outcome!.correct, 1);
      expect(outcome!.total, 2);
    });

    testWidgets('a clean series reports every item correct',
        (WidgetTester tester) async {
      // The control: an `outcomes` that always reported a slip would satisfy
      // the ordering test above on its wrong half alone.
      RoundOutcome? outcome;
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RoundScreen(
            items: _twoItems,
            onFinished: (RoundOutcome result) => outcome = result,
          ),
        ),
      );

      for (final String id in <String>['4', '2', 'submit']) {
        await _press(tester, id);
      }
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      for (final String id in <String>['6', 'submit']) {
        await _press(tester, id);
      }
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(outcome!.outcomes, <Verdict>[Verdict.correct, Verdict.correct]);
      expect(outcome!.stumble, isNull, reason: 'nothing went wrong to explain');
    });

    testWidgets('the first slip is the one carried out, not the last',
        (WidgetTester tester) async {
      // `2.5` explains one mistake. The earliest is the one that most likely
      // caused the rest, and picking the latest would rewrite the block every
      // time a tired player slipped again at the end.
      RoundOutcome? outcome;
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RoundScreen(
            items: _twoItems,
            fallbackDiagnosis: const Diagnosis(
              steps: <String>['Revisa la cuenta paso por paso.'],
              explain: 'Vuelve a leer los numeros con calma.',
            ),
            onFinished: (RoundOutcome result) => outcome = result,
          ),
        ),
      );

      // Wrong on both, so "first" and "last" are distinguishable only if the
      // round is actually keeping the first.
      for (final String id in <String>['7', 'submit']) {
        await _press(tester, id);
      }
      await tester.tap(find.text('Intentar otro'));
      await tester.pumpAndSettle();
      for (final String id in <String>['8', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Intentar otro'));
      await tester.pumpAndSettle();

      expect(outcome!.outcomes, <Verdict>[Verdict.wrong, Verdict.wrong]);
      expect(outcome!.stumble, isNotNull);
      expect(outcome!.stumbleIndex, 0);
    });

    testWidgets('a pack with no diagnosis copy carries no explanation',
        (WidgetTester tester) async {
      // Absent rather than invented: the copy is the pack's, and a round that
      // was given none has nothing true to say about the slip.
      RoundOutcome? outcome;
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RoundScreen(
            items: _twoItems,
            onFinished: (RoundOutcome result) => outcome = result,
          ),
        ),
      );

      for (final String id in <String>['7', 'submit']) {
        await _press(tester, id);
      }
      await tester.tap(find.text('Intentar otro'));
      await tester.pumpAndSettle();
      for (final String id in <String>['8', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Intentar otro'));
      await tester.pumpAndSettle();

      expect(outcome!.stumble, isNull);
      expect(outcome!.stumbleIndex, isNull);
    });
  });
}
