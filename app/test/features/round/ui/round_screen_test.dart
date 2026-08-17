import 'package:akimath_app/content/model/item.dart';
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

    testWidgets('the next press after a verdict moves on',
        (WidgetTester tester) async {
      await _pump(tester);
      await _press(tester, '4');
      await _press(tester, '2');
      await _press(tester, 'submit');
      expect(find.byType(VerdictRing), findsOneWidget);

      // The press that dismisses a verdict is consumed, not typed: a player
      // reaching for the pad after seeing a result should not seed the next
      // answer with whatever they happened to hit.
      await _press(tester, '7');
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
}
