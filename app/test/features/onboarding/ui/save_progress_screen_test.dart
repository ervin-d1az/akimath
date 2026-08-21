import 'package:akimath_app/demo/demo_figures.dart';
import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:akimath_app/features/onboarding/ui/save_progress_screen.dart';
import 'package:akimath_app/features/shell/ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  int challenges = 6,
  int days = 1,
  VoidCallback? onCreateAccount,
  VoidCallback? onLater,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AkiMathTheme.build(),
      home: AppShell(
        child: SaveProgressScreen(
          challenges: challenges,
          days: days,
          onCreateAccount: onCreateAccount,
          onLater: onLater ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('it asks the design\'s question', (WidgetTester tester) async {
    await _pump(tester, onCreateAccount: () {});

    expect(find.text('¿TE LO GUARDO?'), findsOneWidget);
  });

  testWidgets('the retos and the día are what the caller measured',
      (WidgetTester tester) async {
    await _pump(tester, challenges: 6, days: 1, onCreateAccount: () {});

    expect(find.text('6'), findsOneWidget);
    expect(find.text('RETOS'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('DÍA'), findsOneWidget);
  });

  testWidgets('and they change with the figures handed in',
      (WidgetTester tester) async {
    // The control: without it the two above pass for a screen of constants.
    await _pump(tester, challenges: 3, days: 12, onCreateAccount: () {});

    expect(find.text('3'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('DÍAS'), findsOneWidget);
  });

  testWidgets('the rating tile is the quarantined figure',
      (WidgetTester tester) async {
    await _pump(tester, onCreateAccount: () {});

    expect(find.text(EsMxNumber.integer(DemoFigures.rating)), findsOneWidget);
    expect(find.text('RATING'), findsOneWidget);
  });

  testWidgets('it says what happens if the player does nothing',
      (WidgetTester tester) async {
    await _pump(tester, onCreateAccount: () {});

    expect(
      find.text('Si cierras la app sin cuenta, esto se queda en este teléfono.'),
      findsOneWidget,
    );
  });

  testWidgets('Aki is at rest here, because nothing is being solved',
      (WidgetTester tester) async {
    await _pump(tester, onCreateAccount: () {});

    expect(tester.widget<Aki>(find.byType(Aki)).pose, AkiPose.base);
  });

  testWidgets('the green button asks for an account', (WidgetTester tester) async {
    int asked = 0;
    int later = 0;
    await _pump(
      tester,
      onCreateAccount: () => asked++,
      onLater: () => later++,
    );

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(asked, 1);
    expect(later, 0);
  });

  testWidgets('and the quiet one moves on', (WidgetTester tester) async {
    int asked = 0;
    int later = 0;
    await _pump(
      tester,
      onCreateAccount: () => asked++,
      onLater: () => later++,
    );

    await tester.tap(find.text('Después'));
    await tester.pumpAndSettle();

    expect(later, 1);
    expect(asked, 0);
  });

  testWidgets('with no account flow wired, it offers nothing it cannot do',
      (WidgetTester tester) async {
    // DR-P2, the same reading as the profile drawing no account row in a build
    // that has no auth URL: a button that goes nowhere is worse than no
    // button. The way on is still there.
    await _pump(tester);

    expect(find.text('Crear cuenta'), findsNothing);
    expect(find.text('Después'), findsOneWidget);
  });
}
