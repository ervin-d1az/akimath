import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/features/profile/ui/profile_screen.dart';
import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('4.1 Perfil — who you are', () {
    testWidgets('the identity row carries Aki in a tile and the address',
        (WidgetTester tester) async {
      await pump(
        tester,
        ProfileScreen(
          accountEmail: 'ana@correo.mx',
          accountState: AccountState.linked,
          onOpenSettings: () {},
        ),
      );

      expect(find.byType(Aki), findsOneWidget);
      expect(find.text('ana@correo.mx'), findsOneWidget);
    });

    testWidgets('the gear is the only way onward, and it works',
        (WidgetTester tester) async {
      int opened = 0;
      await pump(
        tester,
        ProfileScreen(
          accountEmail: 'ana@correo.mx',
          accountState: AccountState.linked,
          onOpenSettings: () => opened++,
        ),
      );

      final Iterable<BrandGlyph> glyphs = tester
          .widgetList<BrandIcon>(find.byType(BrandIcon))
          .map((BrandIcon icon) => icon.glyph);
      expect(glyphs, contains(BrandGlyph.gear));

      await tester.tap(find.bySemanticsLabel('Ajustes'));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('a device with no account is offered one', (WidgetTester tester) async {
      int created = 0;
      await pump(
        tester,
        ProfileScreen(
          accountState: AccountState.none,
          onOpenSettings: () {},
          onCreateAccount: () => created++,
        ),
      );

      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      expect(created, 1);
    });

    testWidgets('a build with no endpoints offers nothing it cannot do',
        (WidgetTester tester) async {
      // DR-P2 again: `onCreateAccount` is null when the build was given no
      // auth URL, and a button that can only fail is worse than an absent one.
      await pump(
        tester,
        ProfileScreen(accountState: AccountState.none, onOpenSettings: () {}),
      );

      expect(find.text('Crear cuenta'), findsNothing);
    });
  });

  group('what it does not print', () {
    testWidgets('no rating, no accuracy, no mean time', (WidgetTester tester) async {
      // Each is F4 or needs an aggregate no endpoint answers. The same reading
      // that keeps a rating off the verdict screens and off 4.13.
      await pump(
        tester,
        ProfileScreen(
          accountEmail: 'ana@correo.mx',
          accountState: AccountState.linked,
          onOpenSettings: () {},
        ),
      );

      for (final String absent in <String>[
        'RATING',
        'ACIERTOS',
        'PROMEDIO',
        'RETOS',
      ]) {
        expect(find.textContaining(absent), findsNothing, reason: absent);
      }
    });

    testWidgets('no history, because Avance already reads that feed',
        (WidgetTester tester) async {
      // Two screens over one feed can disagree, and the recorded decision is
      // that what a player has done is not a setting — it is Avance.
      await pump(
        tester,
        ProfileScreen(
          accountEmail: 'ana@correo.mx',
          accountState: AccountState.linked,
          onOpenSettings: () {},
        ),
      );

      expect(find.textContaining('HISTORIAL'), findsNothing);
    });
  });
}
