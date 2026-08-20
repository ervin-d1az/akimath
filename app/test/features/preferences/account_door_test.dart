import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the account door is on the profile root.
///
/// **This exists because the claim was made and was wrong.** The route read
/// `Endpoints.configured`, a compile-time constant no test could vary, so
/// "the button appears when the build is configured" was an assertion rather
/// than a fact — and the first simulator build reused a cached kernel, the
/// `--dart-define`s never landed, and the row silently did not render.
void main() {
  Future<void> pump(WidgetTester tester, {required String authBaseUrl}) async {
    await tester.pumpWidget(MaterialApp(
      home: ProfileRoute(
        now: () => DateTime.utc(2026, 8, 19),
        authBaseUrl: authBaseUrl,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a configured build offers the door', (WidgetTester tester) async {
    await pump(tester, authBaseUrl: 'https://auth.example/neondb/auth');

    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets('a build with no endpoints offers nothing to press',
      (WidgetTester tester) async {
    // Absent rather than broken: a button that can only fail is worse than no
    // button, the same reading that keeps every do-nothing toggle off (DR-P2).
    await pump(tester, authBaseUrl: '');

    expect(find.text('Crear cuenta'), findsNothing);
    // The row still says what is true — there is no account here — because a
    // screen that vanishes and a screen that says nothing are different
    // failures and only one of them is this one.
    expect(find.text('Sin cuenta en este teléfono'), findsOneWidget);
  });
}
