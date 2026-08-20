import 'package:akimath_app/features/preferences/policy/erasure.dart';
import 'package:akimath_app/design/widgets/settings_row.dart';
import 'package:akimath_app/features/preferences/ui/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(
  WidgetTester tester, {
  VoidCallback? onErase,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AccountScreen(
          onBack: () {},
          email: 'alguien@ejemplo.com',
          onErase: onErase,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reports the address without pretending it opens something',
      (WidgetTester tester) async {
    await pump(tester);

    expect(find.text('CORREO'), findsOneWidget);
    expect(find.text('alguien@ejemplo.com'), findsOneWidget);
    // A card rather than a row with a trailing value: a chevron would say
    // *there is more through here*, and an address is four times the width of
    // the `19:30` the design's value-bearing row was drawn for.
    expect(find.byType(SettingsRow), findsNothing);
  });

  testWidgets('a long address still fits at the text setting we are gated for',
      (WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: Scaffold(
            body: AccountScreen(
              onBack: () {},
              email: 'nombre.muy.largo.de.persona@correo-electronico.com.mx',
              onErase: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('the door out of an account', () {
    testWidgets('is drawn where a session could carry the request',
        (WidgetTester tester) async {
      await pump(tester, onErase: () {});

      expect(find.text(erasureDoorLabel), findsOneWidget);
    });

    testWidgets('and is absent rather than dead when it could only fail',
        (WidgetTester tester) async {
      // The route decides that — `erasureOffered` — and hands null. A control
      // that can only produce an error is worse than no control (DR-P2).
      await pump(tester);

      expect(find.text(erasureDoorLabel), findsNothing);
    });

    testWidgets('pressing it asks the caller, and asks nothing itself',
        (WidgetTester tester) async {
      // No dialog from here. The question is a screen of its own, because it
      // has to fit a sentence about what survives, and a Material dialog is not
      // a surface this app draws.
      int opened = 0;
      await pump(tester, onErase: () => opened++);

      await tester.tap(find.text(erasureDoorLabel));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('the design\'s other two rows are absent, not inert',
        (WidgetTester tester) async {
      // `Cambiar contraseña` needs a Neon Auth flow nobody has built, and
      // `Cerrar sesión` needs somewhere for a signed-out device to go that is
      // not the erasure's answer (DR-P2).
      await pump(tester, onErase: () {});

      expect(find.text('Cambiar contraseña'), findsNothing);
      expect(find.text('Cerrar sesión'), findsNothing);
    });
  });
}
