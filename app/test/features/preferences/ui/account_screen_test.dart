import 'package:akimath_app/features/preferences/policy/erasure.dart';
import 'package:akimath_app/design/widgets/settings_row.dart';
import 'package:akimath_app/features/preferences/ui/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(
  WidgetTester tester, {
  VoidCallback? onErase,
  VoidCallback? onChangePassword,
  VoidCallback? onSignOut,
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
          onChangePassword: onChangePassword,
          onSignOut: onSignOut,
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
    // the `19:30` the design's value-bearing row was drawn for. The other rows
    // *are* `SettingsRow`s, so this is scoped to the address rather than to the
    // type.
    expect(
      find.widgetWithText(SettingsRow, 'alguien@ejemplo.com'),
      findsNothing,
    );
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

  });

  group('the other two rows the design draws', () {
    testWidgets('are there when the caller can act on them',
        (WidgetTester tester) async {
      await pump(tester, onChangePassword: () {}, onSignOut: () {});

      expect(find.text('Cambiar contraseña'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('and absent rather than inert when it cannot',
        (WidgetTester tester) async {
      // Same reading as the erasure door: a control that cannot act reads as
      // broken rather than as unbuilt, and a player cannot tell *not yet* from
      // *not for you* (DR-P2).
      await pump(tester);

      expect(find.text('Cambiar contraseña'), findsNothing);
      expect(find.text('Cerrar sesión'), findsNothing);
    });

    testWidgets('each asks its own caller, once', (WidgetTester tester) async {
      int changed = 0;
      int signedOut = 0;
      await pump(
        tester,
        onChangePassword: () => changed++,
        onSignOut: () => signedOut++,
      );

      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();
      expect(<int>[changed, signedOut], <int>[1, 0]);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(<int>[changed, signedOut], <int>[1, 1]);
    });

    testWidgets('and only the one that opens something promises it',
        (WidgetTester tester) async {
      // `SettingsRow`'s own rule: the chevron says *there is more through
      // here*, so a row that acts in place draws none. Signing out stays on
      // this screen; changing a password is a screen away.
      await pump(tester, onChangePassword: () {}, onSignOut: () {});

      final SettingsRow opens =
          tester.widget(find.widgetWithText(SettingsRow, 'Cambiar contraseña'));
      final SettingsRow acts =
          tester.widget(find.widgetWithText(SettingsRow, 'Cerrar sesión'));

      expect(opens.showChevron, isTrue);
      expect(acts.showChevron, isFalse);
    });

    testWidgets('and the four rows are in the order the design lists them',
        (WidgetTester tester) async {
      await pump(
        tester,
        onErase: () {},
        onChangePassword: () {},
        onSignOut: () {},
      );

      final double correo = tester.getTopLeft(find.text('CORREO')).dy;
      final double password =
          tester.getTopLeft(find.text('Cambiar contraseña')).dy;
      final double signOut = tester.getTopLeft(find.text('Cerrar sesión')).dy;
      final double erase = tester.getTopLeft(find.text(erasureDoorLabel)).dy;

      expect(correo, lessThan(password));
      expect(password, lessThan(signOut));
      expect(signOut, lessThan(erase));
    });
  });
}
