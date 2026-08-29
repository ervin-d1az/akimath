import 'package:akimath_app/api/endpoints.dart';
import 'package:akimath_app/features/auth/policy/adults_only_copy.dart';
import 'package:akimath_app/features/auth/ui/adults_only_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/launch.dart';

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
///
/// **It asks for a device past the first run, and a cleared one.** This suite is
/// about the door, not the onboarding — and `TU CUENTA` offering *"Crear
/// cuenta"* is a claim about a device holding no session and no player id, which
/// `launchOnTheHome` establishes rather than inherits.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the account door leads to the age gate and then to the form',
      (WidgetTester tester) async {
    await launchOnTheHome(tester);

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
      await pressKey(tester, digit);
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

  testWidgets('a minor is refused, and no path from there reaches the form',
      (WidgetTester tester) async {
    await launchOnTheHome(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    // **A date, not an age, and it has to stay a minor's.** This suite reads
    // the real clock — `ProfileRoute` passes `DateTime.now()` into the flow —
    // so a date pinned to the boundary is a minor for one run and an adult for
    // the next. Born 19/08/2011: fifteen today, still `13_17` until 2029, and
    // `13_17` is the band that reached this form and synced until ADR 0004.
    // Ten years old would exercise the arm that was already closed.
    for (final String digit in '19082011'.split('')) {
      await pressKey(tester, digit);
    }
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.byType(AdultsOnlyScreen), findsOneWidget);
    expect(find.byKey(const Key('create-account-email')), findsNothing);

    // The one way on is out of the flow. The trail is cleared on the way in, so
    // there is nothing behind the refusal to step back into.
    await tester.tap(find.text(adultsOnlyDoorLabel));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-account-email')), findsNothing);
    expect(find.byType(AdultsOnlyScreen), findsNothing);
  }, skip: !Endpoints.configured);

  testWidgets('the form refuses a short password without leaving the device',
      (WidgetTester tester) async {
    await launchOnTheHome(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    for (final String digit in '14031990'.split('')) {
      await pressKey(tester, digit);
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
