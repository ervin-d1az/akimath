import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/features/states/ui/offline_screen.dart';
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

OfflineScreen bag({
  int challenges = 40,
  int puzzles = 2,
  VoidCallback? onSolveOffline,
}) => OfflineScreen(
  challenges: challenges,
  puzzles: puzzles,
  onSolveOffline: onSolveOffline ?? () {},
);

void main() {
  group('Sin conexión', () {
    testWidgets('counts the bag in the headline and in the tally', (
      WidgetTester tester,
    ) async {
      await pump(tester, bag());

      expect(find.text('TRAES 40 RETOS'), findsOneWidget);
      expect(find.text('EN LA BOLSA'), findsOneWidget);
      expect(find.text('PAQUETE DESCARGADO'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('RETOS'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('PUZZLES'), findsOneWidget);
    });

    // *"Sin conexión no es un error del usuario: va en amarillo."* The banner
    // is drawn by the state itself rather than by the shell's slot, because
    // `fullScreenSession` has no slot — and the design puts it inside the
    // screen it draws.
    testWidgets('leads with the notice, and the notice is not an error', (
      WidgetTester tester,
    ) async {
      await pump(tester, bag());

      expect(
        find.text('Sin conexión · se sincroniza al volver'),
        findsOneWidget,
      );
      expect(find.byType(OfflineNotice), findsOneWidget);
    });

    testWidgets('Aki is here — losing signal is nobody\'s mistake', (
      WidgetTester tester,
    ) async {
      await pump(tester, bag());

      expect(find.byType(Aki), findsOneWidget);
    });

    // The design writes *"Tu rating se guarda aquí…"*. Rating is F4 and
    // `GET /me/standing` returns no figure, so the sentence keeps the half
    // that is true — the same carve-out `StreakLostScreen` already took.
    testWidgets('promises what is stored, and never a rating', (
      WidgetTester tester,
    ) async {
      await pump(tester, bag());

      expect(
        find.text(
          'Lo que resuelvas se guarda aquí y se pone al día cuando haya señal.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('rating'), findsNothing);
      expect(find.textContaining('Rating'), findsNothing);
    });

    testWidgets('the one way out plays the pack that is already here', (
      WidgetTester tester,
    ) async {
      int solved = 0;
      await pump(tester, bag(onSolveOffline: () => solved++));

      expect(find.text('Resolver sin conexión'), findsOneWidget);
      await tester.tap(find.text('Resolver sin conexión'));
      await tester.pump();

      expect(solved, 1);
    });

    testWidgets('a singular bag reads singular throughout', (
      WidgetTester tester,
    ) async {
      await pump(tester, bag(challenges: 1, puzzles: 1));

      expect(find.text('TRAES 1 RETO'), findsOneWidget);
      expect(find.text('RETO'), findsOneWidget);
      expect(find.text('PUZZLE'), findsOneWidget);
    });

    testWidgets('a pack with no boards draws no puzzle pile', (
      WidgetTester tester,
    ) async {
      await pump(tester, bag(challenges: 40, puzzles: 0));

      expect(find.text('PUZZLES'), findsNothing);
      expect(find.text('RETOS'), findsOneWidget);
    });
  });
}
