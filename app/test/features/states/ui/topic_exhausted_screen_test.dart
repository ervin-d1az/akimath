import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/features/states/policy/topic_suggestion.dart';
import 'package:akimath_app/features/states/ui/topic_exhausted_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(textDirection: TextDirection.ltr, child: screen),
  );
}

TopicExhaustedScreen exhausted({
  VoidCallback? onOpenTopic,
  VoidCallback? onOpenPuzzle,
  VoidCallback? onSwitch,
}) => TopicExhaustedScreen(
  skillName: 'Fracciones',
  nextTopic: const NextTopic(
    name: 'Decimales',
    percent: 38,
    readyCount: 5,
  ),
  puzzleSubtitle: 'KenKen · 15 min, sin prisa',
  onOpenTopic: onOpenTopic ?? () {},
  onOpenPuzzle: onOpenPuzzle ?? () {},
  onSwitch: onSwitch ?? () {},
);

void main() {
  group('Se acabó el tema', () {
    testWidgets('says what ran out and when there is more', (
      WidgetTester tester,
    ) async {
      await pump(tester, exhausted());

      expect(find.text('YA NO ME QUEDAN'), findsOneWidget);
      expect(find.text('FRACCIONES HOY'), findsOneWidget);
      expect(
        find.text(
          'Mañana hay más, y llegan un poco más difíciles. '
          'Mientras, puedes moverte de tema.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers the two places left to go', (
      WidgetTester tester,
    ) async {
      await pump(tester, exhausted());

      expect(find.text('Decimales'), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);
      expect(find.text('5 retos listos'), findsOneWidget);
      expect(find.text('Puzzle del día'), findsOneWidget);
      expect(find.text('KenKen · 15 min, sin prisa'), findsOneWidget);
    });

    testWidgets('Aki is here — running out is not a failure', (
      WidgetTester tester,
    ) async {
      await pump(tester, exhausted());

      expect(find.byType(Aki), findsOneWidget);
    });

    testWidgets('each row opens its own thing', (WidgetTester tester) async {
      int topic = 0;
      int puzzle = 0;
      await pump(
        tester,
        exhausted(onOpenTopic: () => topic++, onOpenPuzzle: () => puzzle++),
      );

      await tester.tap(find.text('Decimales'));
      await tester.pump();
      await tester.tap(find.text('Puzzle del día'));
      await tester.pump();

      expect(topic, 1);
      expect(puzzle, 1);
    });

    testWidgets('the primary names the topic it switches to', (
      WidgetTester tester,
    ) async {
      int switched = 0;
      await pump(tester, exhausted(onSwitch: () => switched++));

      await tester.tap(find.text('Cambiar a decimales'));
      await tester.pump();

      expect(switched, 1);
    });

    // Tomorrow's items are harder, which is a promise about the ladder and not
    // about a rating. Nothing here prints a figure the server would contradict.
    testWidgets('prints no rating', (WidgetTester tester) async {
      await pump(tester, exhausted());

      expect(find.textContaining('rating'), findsNothing);
      expect(find.textContaining('Rating'), findsNothing);
    });
  });
}
