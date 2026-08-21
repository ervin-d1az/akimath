import 'package:akimath_app/design/widgets/detail_header.dart';
import 'package:akimath_app/features/preferences/data/settings_store.dart';
import 'package:akimath_app/features/preferences/policy/notification_settings.dart';
import 'package:akimath_app/features/preferences/ui/notifications_screen.dart';
import 'package:akimath_app/features/preferences/ui/settings_toggle_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<SettingsStore<NotificationSettings>> pump(
  WidgetTester tester, {
  NotificationSettings initial = NotificationSettings.defaults,
  VoidCallback? onBack,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final SettingsStore<NotificationSettings> store =
      InMemorySettingsStore<NotificationSettings>(initial);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: NotificationsScreen(onBack: onBack ?? () {}, store: store),
    ),
  ));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('4.4 Notificaciones', () {
    testWidgets('has the design\'s header and a way back',
        (WidgetTester tester) async {
      int backs = 0;
      await pump(tester, onBack: () => backs++);

      expect(find.byType(DetailHeader), findsOneWidget);
      expect(find.text('NOTIFICACIONES'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Volver'));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('draws the three switches the design draws, with their notes',
        (WidgetTester tester) async {
      await pump(tester);

      for (final String label in <String>[
        'Recordatorio diario',
        'Racha en riesgo',
        'Puzzle nuevo',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Una vez al día, nada más'), findsOneWidget);
      expect(find.text('Solo si no jugaste y ya va a ser tarde'),
          findsOneWidget);
      expect(find.text('Cuando entra el del día'), findsOneWidget);

      final int rows =
          tester.widgetList<SettingsToggleRow>(find.byType(SettingsToggleRow))
              .length;
      // PROC-10: a screen that silently drew no switches must not pass.
      expect(rows, greaterThan(0), reason: 'toggle rows → $rows');
      expect(rows, NotificationsScreen.toggleCount);
    });

    testWidgets('the hour it shows is the hour that is set, split as drawn',
        (WidgetTester tester) async {
      await pump(tester);

      expect(find.text('¿A QUÉ HORA?'), findsOneWidget);
      // The design draws `19` and `30` in two boxes. They are the selected
      // preset read back, never a figure of the screen's own.
      expect(find.text(ReminderTime.evening.hour), findsWidgets);
      expect(find.text(ReminderTime.evening.minute), findsWidgets);
    });

    testWidgets('choosing another hour changes what the boxes show',
        (WidgetTester tester) async {
      final SettingsStore<NotificationSettings> store = await pump(tester);

      await tester.tap(find.text(ReminderTime.morning.label));
      await tester.pumpAndSettle();

      expect((await store.read()).reminderTime, ReminderTime.morning);
      expect(find.text(ReminderTime.morning.hour), findsWidgets);
    });

    testWidgets('a switch records what it was moved to', (WidgetTester tester) async {
      final SettingsStore<NotificationSettings> store = await pump(tester);
      expect((await store.read()).newPuzzle, isFalse);

      await tester.tap(find.text('Puzzle nuevo'));
      await tester.pumpAndSettle();

      expect((await store.read()).newPuzzle, isTrue);
    });

    testWidgets('it opens at what was stored, not at the defaults',
        (WidgetTester tester) async {
      await pump(
        tester,
        initial: NotificationSettings.defaults
            .copyWith(reminderTime: ReminderTime.night),
      );

      expect(find.text(ReminderTime.night.hour), findsWidgets);
    });

    testWidgets('it says plainly that nothing is sent yet',
        (WidgetTester tester) async {
      // A player who turns a reminder on and never hears from the app would
      // otherwise conclude it is broken. There is no notification plugin, and
      // adding one is a DEP-1 decision rather than a session's.
      await pump(tester);

      expect(find.text(notificationsNotYetSentNotice), findsOneWidget);
    });
  });
}
