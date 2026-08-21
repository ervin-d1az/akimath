import 'package:akimath_app/api/endpoints.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/onboarding/ui/welcome_screen.dart';
import 'package:akimath_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The account door, on a real device, up to the last step that cannot be
/// automated.
///
/// **It stops before submitting, and that is the whole design.** Pressing
/// `Crear cuenta` reaches Neon Auth and creates an account for real; a suite
/// meant to run on every change cannot leave a user row behind each time. So
/// this drives everything up to the form — which is where four of the five bugs
/// in this flow actually were — and the submit stays a human step.
///
/// Skipped when the build has no endpoints: the row is absent by design then,
/// and a test that fails for that reason would be reporting a build flag rather
/// than a defect.
Future<void> _press(WidgetTester tester, String id) async {
  await tester.tap(find.byWidgetPredicate(
    (Widget w) => w is KeypadKeyView && w.data.id == id,
  ));
  await tester.pump();
}

Future<void> _reachHome(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 5));

  if (find.byType(WelcomeScreen).evaluate().isNotEmpty) {
    await tester.tap(find.text('Resolver uno'));
    await tester.pumpAndSettle();
    await _press(tester, '1');
    await _press(tester, '3');
    await _press(tester, 'submit');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
  }

  for (int i = 0; i < 20 && find.byType(HomeScreen).evaluate().isEmpty; i++) {
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }
  expect(find.byType(HomeScreen), findsOneWidget, reason: 'never reached the home');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the account door leads to the age gate and then to the form',
      (WidgetTester tester) async {
    await _reachHome(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('TU CUENTA'), findsOneWidget);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    // `req-age-gate`: the gate is what the door opens onto, not the form.
    expect(find.text('¿CUÁNDO NACISTE?'), findsOneWidget);
    expect(find.byKey(const Key('age-gate-date')), findsOneWidget);

    // An adult's date, typed on the 3×4 pad — the system keyboard never takes
    // digits in this app.
    for (final String digit in '14031990'.split('')) {
      await _press(tester, digit);
    }
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-account-email')), findsOneWidget);
    expect(find.byKey(const Key('create-account-password')), findsOneWidget);
    // Q5: a player has no name, so the form has no field for one.
    expect(find.textContaining('CÓMO TE LLAMO'), findsNothing);
    // D13: no social buttons, and the provider's Google is on Neon's own
    // consent screen besides.
    expect(find.textContaining('Google'), findsNothing);
  }, skip: !Endpoints.configured);

  testWidgets('a child reaches consent, and no path from there reaches the form',
      (WidgetTester tester) async {
    await _reachHome(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    // Ten years old on the day the gate is asked.
    for (final String digit in '19082016'.split('')) {
      await _press(tester, digit);
    }
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Sigue jugando'), findsOneWidget);
    expect(find.byKey(const Key('create-account-email')), findsNothing);

    // The one way on is backwards.
    await tester.tap(find.text('Volver a los retos'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-account-email')), findsNothing);
  }, skip: !Endpoints.configured);

  testWidgets('the form refuses a short password without leaving the device',
      (WidgetTester tester) async {
    await _reachHome(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    for (final String digit in '14031990'.split('')) {
      await _press(tester, digit);
    }
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('create-account-email')), 'alguien@ejemplo.com');
    await tester.enterText(find.byKey(const Key('create-account-password')), 'corta');
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();

    // Still on the form, refused locally — `CredentialRules` runs before the
    // request, so nothing reached the provider and no account was created.
    expect(find.byKey(const Key('create-account-problem')), findsOneWidget);
    expect(find.byKey(const Key('create-account-email')), findsOneWidget);
  }, skip: !Endpoints.configured);
}
