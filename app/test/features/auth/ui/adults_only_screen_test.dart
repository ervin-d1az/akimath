import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/widgets/brand_button.dart';
import 'package:akimath_app/features/auth/policy/adults_only_copy.dart';
import 'package:akimath_app/features/auth/policy/age_gate.dart';
import 'package:akimath_app/features/auth/ui/adults_only_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `req-the-refusal-offers-only-what-it-can-do`.
///
/// These pin the **claims** the screen makes, not the strings it spells — the
/// copy is provisional (see `adults_only_copy.dart`) and the design owner will
/// replace it, at which point a test that had pinned the spelling would either
/// fail for no reason or, worse, pass over a sentence that had stopped being
/// true (PROC-11's sixth bullet, LANG-2).
void main() {
  Future<void> pump(WidgetTester tester, {required VoidCallback onBack}) =>
      tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AdultsOnlyScreen(onBack: onBack))),
      );

  testWidgets('the age it names is the age the gate refuses below',
      (WidgetTester tester) async {
    // **The number on screen and the number in the switch are one number.**
    // A refusal that said "menores de 13" while the gate refused under 18
    // would be false for a fifteen-year-old reading it — LANG-2's exact shape.
    await pump(tester, onBack: () {});

    expect(find.textContaining('${AgeGate.adultAge}'), findsOneWidget);
    // And the age it does *not* name: 13 is a band boundary the gate stopped
    // acting on, so a player must not read it as the threshold.
    expect(find.textContaining('${AgeGate.teenBandAge} años'), findsNothing);
  });

  testWidgets('it claims nothing about what was or was not sent',
      (WidgetTester tester) async {
    // **The screen has two ways in and one of them has already spoken to the
    // server.** From the account door the player typed a date and nothing left
    // the phone; from the sign-in door they signed in, so a provider session
    // exists and `GET /me` was answered. Any sentence about nothing having been
    // sent is true on the first and false on the second, and one screen cannot
    // say it. The screen it replaces did (*"nada se envía"*).
    await pump(tester, onBack: () {});

    for (final String claim in <String>[
      'nada se envía',
      'nada se envió',
      'no se envía',
      'no se envió',
      'no sale de este teléfono',
    ]) {
      expect(find.textContaining(claim), findsNothing, reason: claim);
    }
  });

  testWidgets('one control, it acts, and it is the way back',
      (WidgetTester tester) async {
    // DR-P2: nothing is drawn that cannot act. `BrandButton.onPressed` is
    // non-nullable, so a disabled control cannot even be expressed here — what
    // this checks is the other half, that no *second* control was added whose
    // destination the app cannot deliver.
    bool wentBack = false;
    await pump(tester, onBack: () => wentBack = true);

    expect(find.byType(BrandButton), findsOneWidget);
    await tester.tap(find.byType(BrandButton));
    await tester.pump();

    expect(wentBack, isTrue);
  });

  testWidgets('Aki is on it, and she is not the pose for a mistake',
      (WidgetTester tester) async {
    // A refusal is not a punishment and not an error. `AkiPose.slip` is the
    // wrong answer's pose and belongs on `04 Error`; the player here has done
    // nothing wrong, so the resting pose is the one that reads correctly.
    await pump(tester, onBack: () {});

    final Aki aki = tester.widget<Aki>(find.byType(Aki));
    expect(aki.pose, AkiPose.base);
  });

  testWidgets('what it draws is what the policy holds', (WidgetTester tester) async {
    // The screen is the adapter. Every word it shows comes from
    // `adults_only_copy.dart`, so the design owner replaces the copy in one
    // file and this stays green — and a string typed into the widget instead
    // would not.
    await pump(tester, onBack: () {});

    expect(find.text(adultsOnlyHeadline), findsOneWidget);
    expect(find.text(adultsOnlyDetail), findsOneWidget);
    expect(find.text(adultsOnlyDoorLabel), findsOneWidget);
  });
}
