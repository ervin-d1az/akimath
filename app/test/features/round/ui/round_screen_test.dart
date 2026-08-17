import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/features/round/policy/answer_draft.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/design/widgets/verdict_ring.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Item> _oneItem = <Item>[
  Item(
    id: 't1',
    prompt: <PromptToken>[
      PromptToken.text('14'),
      PromptToken.operator('×'),
      PromptToken.text('3'),
      PromptToken.operator('='),
    ],
    expected: '42',
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

void main() {
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
}
