import 'package:akimath_app/features/preferences/ui/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, {VoidCallback? onBack}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ChangePasswordScreen(onBack: onBack ?? () {})),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('it says it is not built rather than looking built',
      (WidgetTester tester) async {
    await pump(tester);

    expect(find.text(changePasswordHeadline), findsOneWidget);
    expect(find.text(changePasswordDetail), findsOneWidget);
  });

  testWidgets('and offers no field, because it could not honour one',
      (WidgetTester tester) async {
    // The credential lives with the identity provider. A form here would
    // either fail or, worse, look like it had worked.
    await pump(tester);

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('it names who holds the password, and does not blame the player',
      (WidgetTester tester) async {
    // The same honesty the erasure screen owes about the address: what the app
    // cannot do, it says it cannot do.
    await pump(tester);

    expect(changePasswordDetail, contains('cuentas'));
    expect(changePasswordDetail, isNot(contains('error')));
  });

  testWidgets('and there is a way back out', (WidgetTester tester) async {
    // A screen whose whole content is "not yet" is the worst one to be stuck
    // on.
    int back = 0;
    await pump(tester, onBack: () => back++);

    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();

    expect(back, 1);
  });
}
