import 'package:akimath_app/design/widgets/detail_header.dart';
import 'package:akimath_app/design/widgets/settings_row.dart';
import 'package:akimath_app/features/preferences/ui/accessibility_screen.dart';
import 'package:akimath_app/features/preferences/ui/data_privacy_screen.dart';
import 'package:akimath_app/features/preferences/ui/notifications_screen.dart';
import 'package:akimath_app/features/preferences/ui/settings_list_screen.dart';
import 'package:akimath_app/features/preferences/ui/sound_screen.dart';
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
  group('Ajustes', () {
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

      final int rows =
          tester.widgetList<SettingsRow>(find.byType(SettingsRow)).length;
      // PROC-10: a list that silently drew nothing must not pass.
      expect(rows, greaterThan(0), reason: 'settings rows -> $rows');
      expect(rows, SettingsListScreen.rowCount);
    });

    testWidgets('the design\'s five rows come in the order it lists them',
        (WidgetTester tester) async {
      await pump(tester, listScreen());

      final List<String> drawn = tester
          .widgetList<SettingsRow>(find.byType(SettingsRow))
          .map((SettingsRow row) => row.label)
          .toList();

      // `Cómo se leen los retos` is not in the design at all, so it sits after
      // everything that is.
      expect(drawn, <String>[
        'Cuenta',
        'Notificaciones',
        'Accesibilidad',
        'Sonido y vibración',
        'Datos y privacidad',
        'Cómo se leen los retos',
      ]);
    });

    testWidgets('the two rows the caller owns report to the caller',
        (WidgetTester tester) async {
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

    testWidgets('the four settings rows open their screens',
        (WidgetTester tester) async {
      // **Reachability is the thing worth asserting.** These four need nothing
      // the caller holds — no session, no address — so the row opens them
      // itself, and a callback counter would prove only that a closure ran.
      final Map<String, Type> destinations = <String, Type>{
        'Notificaciones': NotificationsScreen,
        'Accesibilidad': AccessibilityScreen,
        'Sonido y vibración': SoundScreen,
        'Datos y privacidad': DataPrivacyScreen,
      };

      await pump(tester, listScreen());
      for (final MapEntry<String, Type> row in destinations.entries) {
        await tester.tap(find.text(row.key));
        await tester.pumpAndSettle();
        expect(find.byType(row.value), findsOneWidget, reason: row.key);

        // Back to the list before the next one. A second `pumpWidget` would
        // reuse the same navigator and leave the pushed screen on top, which
        // is a green test that walked one row and stopped.
        await tester.tap(find.bySemanticsLabel('Volver'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsListScreen), findsOneWidget,
            reason: row.key);
      }
    });

    testWidgets('Ayuda has no design, so it gets no row',
        (WidgetTester tester) async {
      // The last of the design's six with nowhere to go. Absent rather than
      // greyed out: a player cannot tell "not yet" from "not for you" (DR-P2).
      // This turns red the day somebody draws it.
      await pump(tester, listScreen());

      expect(find.text('Ayuda'), findsNothing);
    });
  });
}
