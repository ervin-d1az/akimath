import 'package:akimath_app/design/widgets/detail_header.dart';
import 'package:akimath_app/design/widgets/settings_row.dart';
import 'package:akimath_app/features/preferences/ui/settings_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

Widget listScreen({
  VoidCallback? onBack,
  VoidCallback? onAccount,
  VoidCallback? onLegend,
}) =>
    SettingsListScreen(
      onBack: onBack ?? () {},
      onOpenAccount: onAccount ?? () {},
      onOpenLegend: onLegend ?? () {},
    );

void main() {
  group('4.2 Ajustes', () {
    testWidgets('has a header and a way back', (WidgetTester tester) async {
      int backs = 0;
      await pump(tester, listScreen(onBack: () => backs++));

      expect(find.byType(DetailHeader), findsOneWidget);
      expect(find.text('AJUSTES'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Volver'));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('draws only rows that lead somewhere, and reports the count',
        (WidgetTester tester) async {
      await pump(tester, listScreen());

      final int rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).length;
      // PROC-10: a list that silently drew nothing must not pass.
      expect(rows, greaterThan(0), reason: 'settings rows → $rows');
      expect(rows, SettingsListScreen.rowCount);
    });

    testWidgets('every row it draws opens something', (WidgetTester tester) async {
      int account = 0;
      int legend = 0;
      await pump(
        tester,
        listScreen(onAccount: () => account++, onLegend: () => legend++),
      );

      await tester.tap(find.text('Cuenta'));
      await tester.pump();
      expect(account, 1);

      await tester.tap(find.text('Cómo se leen los retos'));
      await tester.pump();
      expect(legend, 1);
    });

    testWidgets('an undesigned or unbuildable destination gets no row',
        (WidgetTester tester) async {
      // No notification plugin, no audio engine, no help screen — and DR-P2 is
      // that a row leading nowhere is worse than an absent one. Not greyed
      // out either: a player cannot tell "not yet" from "not for you".
      await pump(tester, listScreen());

      for (final String absent in <String>[
        'Notificaciones',
        'Sonido y vibración',
        'Ayuda',
        'Datos y privacidad',
      ]) {
        expect(find.text(absent), findsNothing, reason: absent);
      }
    });

    testWidgets('Accesibilidad is absent today and not on principle',
        (WidgetTester tester) async {
      // The one control in 4.4–4.6 whose DR-P2 reasoning does not survive:
      // four text-size steps map onto a scale the app is already gated at 1.0
      // and 1.3. It arrives as a row, not as an ungreying — and this test is
      // what turns red the day it does, so nobody has to remember.
      await pump(tester, listScreen());

      expect(find.text('Accesibilidad'), findsNothing);
    });
  });
}
