import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/math/math_view.dart';
import 'package:akimath_app/design/widgets/speech_bubble.dart';
import 'package:akimath_app/design/widgets/stat_pill.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Item _preview = Item(
  id: 'p1',
  stimulus: ArithmeticStimulus(<PromptToken>[
    PromptToken.fraction(numerator: '3', denominator: '4'),
    PromptToken.operator('+'),
    PromptToken.fraction(numerator: '2', denominator: '4'),
    PromptToken.operator('='),
  ]),
  expected: '5/4',
  ladderStep: 3,
);

Future<void> _pump(WidgetTester tester, {VoidCallback? onStart}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HomeScreen(
          preview: _preview,
          streakDays: 7,
          onStart: onStart ?? () {},
        ),
      ),
    ),
  );
}

Iterable<String> _copy(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => s.isNotEmpty);

void main() {
  group('the home offers today\'s series and nothing it cannot source', () {
    testWidgets('the five elements F2 can source are present',
        (WidgetTester tester) async {
      await _pump(tester);

      expect(find.byType(Aki), findsOneWidget);
      expect(find.byType(SpeechBubble), findsOneWidget);
      expect(find.text('RETO DEL DÍA'), findsOneWidget);
      expect(find.text('Empezar la serie'), findsOneWidget);
      expect(find.byType(StatPill), findsOneWidget);
    });

    testWidgets('the streak pill is the only pill', (WidgetTester tester) async {
      // It is not a subtraction with a return phase — a streak is a local
      // calendar fact and needs no server (D17).
      await _pump(tester);

      expect(find.byType(StatPill), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('no rating appears, and no placeholder for one',
        (WidgetTester tester) async {
      // Q3: the rating is the server's exclusive authority and there is no
      // server. A greyed-out pill would be a figure sync could contradict.
      await _pump(tester);

      final String all = _copy(tester).join(' ').toLowerCase();
      expect(all, isNot(contains('rating')));
      expect(all, isNot(contains('puntos')));
      expect(all, isNot(contains('nivel')));
    });

    testWidgets('no skills row, no puzzle card, no bottom nav',
        (WidgetTester tester) async {
      await _pump(tester);

      final String all = _copy(tester).join(' ').toUpperCase();
      expect(
        all,
        isNot(contains('TUS HABILIDADES')),
        reason: 'the skills row is dropped by choosing Inicio actualizado',
      );
      expect(all, isNot(contains('PUZZLE')));
      expect(find.byType(BottomNavigationBar), findsNothing);
    });
  });

  group('the preview is the real compositor', () {
    testWidgets('the card composes the item rather than describing it',
        (WidgetTester tester) async {
      // The same widget the round draws, so the preview cannot drift from the
      // item it previews.
      await _pump(tester);

      expect(find.byType(MathView), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsWidgets);
    });

    testWidgets('no solidus reaches the preview', (WidgetTester tester) async {
      await _pump(tester);
      for (final String text in _copy(tester)) {
        expect(text, isNot(contains('/')));
      }
    });
  });

  group('starting the series', () {
    testWidgets('the primary button reports a start once',
        (WidgetTester tester) async {
      int starts = 0;
      await _pump(tester, onStart: () => starts++);

      await tester.tap(find.text('Empezar la serie'));
      await tester.pump();

      expect(starts, 1);
    });
  });

  group('Aki is present here, unlike while solving', () {
    testWidgets('she is at the home width, not the verdict width',
        (WidgetTester tester) async {
      await _pump(tester);
      expect(tester.widget<Aki>(find.byType(Aki)).width, 150);
    });
  });
}
