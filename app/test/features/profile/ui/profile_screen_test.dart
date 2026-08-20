import 'package:akimath_app/api/history.dart';
import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/candy_surface.dart';
import 'package:akimath_app/features/profile/policy/history_view.dart';
import 'package:akimath_app/features/profile/ui/profile_screen.dart';
import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(
  WidgetTester tester, {
  String? accountEmail,
  AccountState accountState = AccountState.none,
  int daysPractised = 0,
  int streakDays = 0,
  HistoryState historyState = HistoryState.noAccount,
  List<HistoryEntry> entries = const <HistoryEntry>[],
  VoidCallback? onCreateAccount,
  VoidCallback? onRetryHistory,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProfileScreen(
          accountEmail: accountEmail,
          accountState: accountState,
          daysPractised: daysPractised,
          streakDays: streakDays,
          historyState: historyState,
          entries: entries,
          onOpenSettings: () {},
          onCreateAccount: onCreateAccount,
          onRetryHistory: onRetryHistory,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

HistoryEntry entry(String title, String score) => HistoryEntry(
      at: DateTime.utc(2026, 8, 20, 18, 30),
      kind: HistoryKind.series,
      title: title,
      score: score,
      ratingDelta: null,
    );

void main() {
  group('4.1 Perfil — who you are, and what you have done', () {
    testWidgets('the identity row comes first', (WidgetTester tester) async {
      await pump(
        tester,
        accountEmail: 'ana@correo.mx',
        accountState: AccountState.linked,
        daysPractised: 13,
        streakDays: 5,
      );

      expect(find.byType(Aki), findsOneWidget);
      expect(find.text('ana@correo.mx'), findsOneWidget);
      expect(
        tester.getCenter(find.text('ana@correo.mx')).dy,
        lessThan(tester.getCenter(find.text('RACHA')).dy),
      );
    });

    testWidgets('the gear opens the stack', (WidgetTester tester) async {
      await pump(tester, accountEmail: 'ana@correo.mx');

      final Iterable<BrandGlyph> glyphs = tester
          .widgetList<BrandIcon>(find.byType(BrandIcon))
          .map((BrandIcon icon) => icon.glyph);
      expect(glyphs, contains(BrandGlyph.gear));
      expect(find.bySemanticsLabel('Ajustes'), findsOneWidget);
    });

    testWidgets('a device with no account is offered one', (WidgetTester tester) async {
      int created = 0;
      await pump(tester, onCreateAccount: () => created++);

      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      expect(created, 1);
    });
  });

  group('the figures the device knows', () {
    testWidgets('are drawn with no account at all', (WidgetTester tester) async {
      // A phone that has never synced still knows what it did. They never
      // needed the network, so they do not wait for it.
      await pump(tester, daysPractised: 13, streakDays: 5);

      expect(find.text('DÍAS'), findsOneWidget);
      expect(find.text('RACHA'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('the run is the filled card and the days are not',
        (WidgetTester tester) async {
      // `4.1` draws a white card beside a yellow one, and the filled one is the
      // figure the screen is about. Two identical tiles say the two figures
      // rank equally, which is not what the design says.
      await pump(tester, daysPractised: 13, streakDays: 5);

      final Iterable<Color> fills = tester
          .widgetList<CandySurface>(find.byType(CandySurface))
          .map((CandySurface s) => s.background);

      expect(fills, contains(BrandColors.yellow));
    });

    testWidgets('each figure names its unit', (WidgetTester tester) async {
      // A bare number in a box is a number somebody has to guess at.
      await pump(tester, daysPractised: 13, streakDays: 5);

      expect(find.text('practicando'), findsOneWidget);
      expect(find.text('días seguidos'), findsOneWidget);
    });

    testWidgets('one day is singular', (WidgetTester tester) async {
      await pump(tester, daysPractised: 1, streakDays: 1);

      expect(find.text('día seguido'), findsOneWidget);
    });

    testWidgets('zero is a number, not a gap', (WidgetTester tester) async {
      // The same figure a player has on their first launch, and there is no
      // state in which this screen has nothing to say.
      await pump(tester);

      expect(find.text('0'), findsNWidgets(2));
    });
  });

  group('the history the server knows', () {
    testWidgets('has no heading when there is nothing true to say',
        (WidgetTester tester) async {
      await pump(tester, historyState: HistoryState.noAccount);

      expect(find.text('HISTORIAL'), findsNothing);
    });

    testWidgets('is drawn when the server answered with sessions',
        (WidgetTester tester) async {
      await pump(
        tester,
        accountEmail: 'ana@correo.mx',
        accountState: AccountState.linked,
        historyState: HistoryState.ready,
        entries: <HistoryEntry>[entry('Serie de fracciones', '4 de 5')],
      );

      expect(find.text('HISTORIAL'), findsOneWidget);
      expect(find.text('Serie de fracciones'), findsOneWidget);
      expect(find.text('4 de 5'), findsOneWidget);
    });

    testWidgets('a failure does not take the figures with it',
        (WidgetTester tester) async {
      // **The two halves fail independently.** The figures come from storage
      // and are always available; the history needs a session and a network. A
      // screen that hid one behind the other would hide what the device knows
      // behind a request that may never answer.
      await pump(
        tester,
        accountEmail: 'ana@correo.mx',
        accountState: AccountState.linked,
        daysPractised: 13,
        streakDays: 5,
        historyState: HistoryState.offline,
        onRetryHistory: () {},
      );

      expect(find.text('13'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.byKey(const Key('history-banner')), findsOneWidget);
    });

    testWidgets('no rating column, because there is no rating',
        (WidgetTester tester) async {
      await pump(
        tester,
        accountEmail: 'ana@correo.mx',
        accountState: AccountState.linked,
        historyState: HistoryState.ready,
        entries: <HistoryEntry>[entry('Serie mixta', '5 de 5')],
      );

      for (final String absent in <String>['RATING', 'Rating', 'rating', '±']) {
        expect(find.textContaining(absent), findsNothing, reason: absent);
      }
    });
  });

  group('what does not come across from Avance', () {
    testWidgets('Aki is in the tile and nowhere else', (WidgetTester tester) async {
      // Declared rule 5 names her homes: *inicio, resultados, estados de racha
      // y tutorial*. The profile is not one, and `4.1` draws her only inside
      // the avatar tile. A warm line is a poor reason to break a rule the same
      // document states.
      await pump(tester, accountEmail: 'ana@correo.mx', daysPractised: 13);

      expect(find.byType(Aki), findsOneWidget);
      expect(find.textContaining('Cada día que juegas'), findsNothing);
    });

    testWidgets('and no aggregate the server cannot answer', (WidgetTester tester) async {
      await pump(tester, accountEmail: 'ana@correo.mx', daysPractised: 13);

      for (final String absent in <String>['ACIERTOS', 'PROMEDIO', 'RETOS', '%']) {
        expect(find.textContaining(absent), findsNothing, reason: absent);
      }
    });
  });
}
