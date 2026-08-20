import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/widgets/before_after_counters.dart';
import 'package:akimath_app/design/widgets/streak_badge.dart';
import 'package:akimath_app/features/states/ui/streak_at_risk_screen.dart';
import 'package:akimath_app/features/states/ui/streak_lost_screen.dart';
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

void main() {
  group('4.12 Racha en riesgo', () {
    testWidgets('names the stake, the ask and the runway', (WidgetTester tester) async {
      await pump(
        tester,
        StreakAtRiskScreen(
          days: 13,
          left: const Duration(hours: 3, minutes: 46),
          onSolve: () {},
          onLater: () {},
        ),
      );

      expect(find.byType(StreakBadge), findsOneWidget);
      expect(find.text('HOY TODAVÍA NO'), findsOneWidget);
      expect(find.text('RESUELVES NADA'), findsOneWidget);
      expect(
        find.text('Con un reto de cuatro minutos queda cerrado el día.'),
        findsOneWidget,
      );
      expect(find.textContaining('TE QUEDAN'), findsOneWidget);
      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('Aki is here, because this is not a solve', (WidgetTester tester) async {
      await pump(
        tester,
        StreakAtRiskScreen(
          days: 13,
          left: const Duration(hours: 3, minutes: 46),
          onSolve: () {},
          onLater: () {},
        ),
      );

      expect(find.byType(Aki), findsOneWidget);
    });

    testWidgets('both ways out do what they say', (WidgetTester tester) async {
      int solved = 0;
      int later = 0;
      await pump(
        tester,
        StreakAtRiskScreen(
          days: 13,
          left: const Duration(hours: 3, minutes: 46),
          onSolve: () => solved++,
          onLater: () => later++,
        ),
      );

      await tester.tap(find.text('Resolver uno ahora'));
      await tester.pump();
      expect(solved, 1);

      await tester.tap(find.text('Ahora no'));
      await tester.pump();
      expect(later, 1);
    });

    testWidgets('the second action does not promise a reminder', (WidgetTester tester) async {
      // The design offers `Recuérdame a las 21:00`. There is no notification
      // plugin in `pubspec.yaml` and any candidate must clear the no-phone-home
      // rule first, so a button saying it would be a button that cannot do its
      // job — DR-P2, the same reading that keeps every toggle off Ajustes.
      await pump(
        tester,
        StreakAtRiskScreen(
          days: 13,
          left: const Duration(hours: 3, minutes: 46),
          onSolve: () {},
          onLater: () {},
        ),
      );

      expect(find.textContaining('Recuérdame'), findsNothing);
    });
  });

  group('4.13 Racha perdida', () {
    testWidgets('turns the page from what was to what is', (WidgetTester tester) async {
      await pump(tester, StreakLostScreen(brokenRun: 13, onStart: () {}));

      expect(find.text('LA RACHA'), findsOneWidget);
      expect(find.text('VOLVIÓ A UNO'), findsOneWidget);
      expect(find.byType(BeforeAfterCounters), findsOneWidget);
      expect(find.text('AYER'), findsOneWidget);
      expect(find.text('HOY'), findsOneWidget);
    });

    testWidgets('prints no rating, because there is none to print', (WidgetTester tester) async {
      // The design reassures with `Tu rating sigue donde lo dejaste` and a
      // figure of 1 248. Rating is F4 and `GET /me/standing` answers 501; a
      // promise about a number the player has never seen is worse than
      // silence. The same reading keeps a rating off the verdict screens.
      await pump(tester, StreakLostScreen(brokenRun: 13, onStart: () {}));

      expect(find.textContaining('rating'), findsNothing);
      expect(find.textContaining('Rating'), findsNothing);
      expect(find.textContaining('RATING'), findsNothing);
    });

    testWidgets('has one way forward and takes it', (WidgetTester tester) async {
      int started = 0;
      await pump(tester, StreakLostScreen(brokenRun: 13, onStart: () => started++));

      await tester.tap(find.text('Empezar la de hoy'));
      await tester.pump();
      expect(started, 1);
    });

    testWidgets('does not scold', (WidgetTester tester) async {
      // Annotated *"se pasa la página"*: no consolation, no reproach, one
      // forward action. Aki does not look disappointed and the copy does not
      // either.
      await pump(tester, StreakLostScreen(brokenRun: 13, onStart: () {}));

      for (final String scolding in <String>[
        'perdiste',
        'Perdiste',
        'fallaste',
        'lástima',
        'Lástima',
      ]) {
        expect(find.textContaining(scolding), findsNothing, reason: scolding);
      }
    });
  });

  group('a finger can land on the ways out', () {
    // The registry gate reports a sweep across every screen; this pins the two
    // added here, so a press that stops being found reads as a failure and not
    // as one fewer row in a total.
    testWidgets('4.12 offers two presses, both at the floor', (WidgetTester tester) async {
      await pump(
        tester,
        StreakAtRiskScreen(
          days: 13,
          left: const Duration(hours: 3, minutes: 46),
          onSolve: () {},
          onLater: () {},
        ),
      );

      final Iterable<GestureDetector> presses = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .where((GestureDetector d) => d.onTap != null || d.onTapDown != null);
      expect(presses, hasLength(2));

      for (final Element element in find.byType(GestureDetector).evaluate()) {
        final RenderBox box = element.renderObject! as RenderBox;
        expect(box.size.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('4.13 offers one', (WidgetTester tester) async {
      await pump(tester, StreakLostScreen(brokenRun: 13, onStart: () {}));

      final Iterable<GestureDetector> presses = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .where((GestureDetector d) => d.onTap != null || d.onTapDown != null);
      expect(presses, hasLength(1));
    });
  });
}
