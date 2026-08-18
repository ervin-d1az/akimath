import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/math/math_view.dart';
import 'package:akimath_app/design/widgets/speech_bubble.dart';
import 'package:akimath_app/features/home/ui/bands/week_strip.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/shell/ui/app_shell.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onStart,
  int streakDays = 7,
  List<bool>? weekMarks,
  List<String> todaysFamilies = const <String>['Cuentas', 'Series'],
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HomeScreen(
          preview: _preview,
          streakDays: streakDays,
          weekMarks: weekMarks ??
              const <bool>[true, true, true, true, true, true, true],
          todaysFamilies: todaysFamilies,
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
  group('the preview draws whatever family the day begins with', () {
    // `HomeRoute` hands over `pack.items.first`, and the pack is interleaved:
    // which family lands first is a content decision, not a code one. The card
    // called `nodeFor`, which throws on anything that is not an expression, so
    // reordering the pack would have crashed the home on launch.
    const Map<String, Stimulus> families = <String, Stimulus>{
      'series': NumberSeriesStimulus(terms: <int>[2, 4, 6, 8], unknownIndex: 3),
      'matrix': MatrixStimulus(cells: <int>[1, 2, 2, 4], size: 2, unknownIndex: 3),
      'analogy': AnalogyStimulus(terms: <int>[2, 4, 5, 10], unknownIndex: 3),
      'machine': HiddenOperationStimulus(
        examples: <({int input, int output})>[
          (input: 2, output: 7),
          (input: 5, output: 16),
        ],
        queryInput: 9,
      ),
      'figurate': FigurateStimulus(dotCounts: <int>[1, 3, 6], unknownIndex: 2),
    };

    for (final MapEntry<String, Stimulus> family in families.entries) {
      testWidgets('a ${family.key} preview renders', (WidgetTester tester) async {
        tester.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: AppShell(
              child: HomeScreen(
                preview: Item(
                  id: family.key,
                  stimulus: family.value,
                  expected: '8',
                  ladderStep: 2,
                ),
                streakDays: 3,
                onStart: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the home offers today\'s series and nothing it cannot source', () {
    testWidgets('the five elements F2 can source are present',
        (WidgetTester tester) async {
      await _pump(tester);

      expect(find.byType(Aki), findsOneWidget);
      expect(find.byType(SpeechBubble), findsOneWidget);
      expect(find.text('RETO DEL DÍA'), findsOneWidget);
      expect(find.text('Empezar la serie'), findsOneWidget);
      expect(find.byType(WeekStrip), findsOneWidget);
    });

    testWidgets('the streak is labelled, not a bare number', (WidgetTester tester) async {
      // It replaced a lone `7` in the corner, which told a player a total they
      // had to trust and named nothing. A streak is a local calendar fact and
      // needs no server (D17), so it is the one figure the F2 home may state.
      await _pump(tester);

      expect(find.text('RACHA'), findsOneWidget);
      expect(find.text('7 DÍAS'), findsOneWidget);
    });

    testWidgets('one day reads in the singular', (WidgetTester tester) async {
      await _pump(tester, streakDays: 1);
      expect(find.text('1 DÍA'), findsOneWidget);
      expect(find.text('1 DÍAS'), findsNothing);
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
