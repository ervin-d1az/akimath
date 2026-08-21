import 'package:akimath_app/api/history.dart';
import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/candy_surface.dart';
import 'package:akimath_app/features/profile/policy/history_view.dart';
import 'package:akimath_app/features/profile/policy/profile_readout.dart';
import 'package:akimath_app/features/profile/ui/profile_screen.dart';
import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the design draws: every figure, invented ones included.
const ProfileFigures drawn = ProfileFigures(
  daysPractised: 13,
  streakDays: 13,
  challenges: 312,
  rating: 1248,
  ratingThisWeek: 36,
  accuracyPercent: 78,
  averageTenthsOfSecond: 68,
);

/// What the product can prove today. The same screen with the invented figures
/// switched off, which is the build that ships.
const ProfileFigures provable = ProfileFigures(
  daysPractised: 13,
  streakDays: 5,
  challenges: 312,
);

Future<void> pump(
  WidgetTester tester, {
  String? accountEmail,
  AccountState accountState = AccountState.none,
  ProfileFigures figures = provable,
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
          figures: figures,
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

  group('the headline pair', () {
    testWidgets('draws the rating and the run the design draws',
        (WidgetTester tester) async {
      await pump(tester, figures: drawn);

      expect(find.text('RATING'), findsOneWidget);
      expect(find.text(EsMxNumber.integer(1248)), findsOneWidget);
      expect(find.text('36 esta semana'), findsOneWidget);
      expect(find.text('RACHA'), findsOneWidget);
      expect(find.text('días seguidos'), findsOneWidget);
    });

    testWidgets('the week gained, so its sign is the success hue',
        (WidgetTester tester) async {
      // The one place a hue appears on this screen, and it is asked for by
      // role. A loss would take the quiet ink instead — the policy decides
      // that, and `profile_readout_test.dart` holds it.
      await pump(tester, figures: drawn);

      final Text sign = tester.widget<Text>(find.text('+'));
      expect(sign.style!.color, BrandColorRole.success.color);
    });

    testWidgets('the run is the filled card and the lead is not',
        (WidgetTester tester) async {
      // `4.1` draws a white card beside a yellow one. Two identical tiles say
      // the two figures rank equally, which is not what the design says.
      await pump(tester, figures: drawn);

      final Iterable<Color> fills = tester
          .widgetList<CandySurface>(find.byType(CandySurface))
          .map((CandySurface surface) => surface.background);

      expect(fills, contains(BrandColors.yellow));
    });

    testWidgets('the wider card is the one the design draws wider',
        (WidgetTester tester) async {
      // `4.1` puts its left card at `flex 1.3` against the right one's `1` —
      // the slot that holds a label, a numeral and a delta line beside one that
      // holds a two-digit count. Fill is half the hierarchy; width is the
      // other, and nothing asserted it until a falsification could not find a
      // test to kill.
      await pump(tester, figures: drawn);

      double cardWidth(String label) => tester
          .getSize(find
              .ancestor(of: find.text(label), matching: find.byType(CandySurface))
              .first)
          .width;

      expect(cardWidth('RATING'), greaterThan(cardWidth('RACHA')));
    });

    testWidgets('with no rating to show, the days lead instead of a hole',
        (WidgetTester tester) async {
      // The branch a build with the invented figures switched off draws, and
      // the reason the wide slot is not left empty: days practised is a figure
      // the device can prove.
      await pump(tester, figures: provable);

      expect(find.text('DÍAS'), findsOneWidget);
      expect(find.text('practicando'), findsOneWidget);
      expect(find.text(EsMxNumber.integer(13)), findsOneWidget);
      expect(find.textContaining('RATING'), findsNothing);
    });

    testWidgets('one day is singular', (WidgetTester tester) async {
      await pump(
        tester,
        figures: const ProfileFigures(
          daysPractised: 1,
          streakDays: 1,
          challenges: 0,
        ),
      );

      expect(find.text('día seguido'), findsOneWidget);
    });
  });

  group('the tile row', () {
    testWidgets('holds the three the design draws', (WidgetTester tester) async {
      await pump(tester, figures: drawn);

      expect(find.text('RETOS'), findsOneWidget);
      expect(find.text('ACIERTOS'), findsOneWidget);
      expect(find.text('PROMEDIO'), findsOneWidget);
      expect(find.text(EsMxNumber.integer(312)), findsOneWidget);
      expect(find.text(EsMxNumber.percent(78)), findsOneWidget);
      expect(find.text(EsMxNumber.seconds(6.8, places: 1)), findsOneWidget);
    });

    testWidgets('keeps the count and drops the rest when nothing else has a source',
        (WidgetTester tester) async {
      // The shipping build. Nothing on this screen is then a figure the device
      // cannot produce, and the row is still a row because the count of
      // challenges is the cursor's, which every phone has.
      await pump(tester, figures: provable);

      expect(find.text('RETOS'), findsOneWidget);
      expect(find.text(EsMxNumber.integer(312)), findsOneWidget);
      for (final String absent in <String>['ACIERTOS', 'PROMEDIO', '%']) {
        expect(find.textContaining(absent), findsNothing, reason: absent);
      }
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
        historyState: HistoryState.offline,
        onRetryHistory: () {},
      );

      expect(find.text(EsMxNumber.integer(13)), findsOneWidget);
      expect(find.text(EsMxNumber.integer(5)), findsOneWidget);
      expect(find.byKey(const Key('history-banner')), findsOneWidget);
    });

    testWidgets('a session row reports no rating, however the headline reads',
        (WidgetTester tester) async {
      // `ratingDelta` is null for every entry a server without rating can
      // produce. The headline may be showing an invented figure; a row is a
      // record of something that happened, and inventing one of those is a
      // different act.
      await pump(
        tester,
        accountEmail: 'ana@correo.mx',
        accountState: AccountState.linked,
        figures: drawn,
        historyState: HistoryState.ready,
        entries: <HistoryEntry>[entry('Serie mixta', '5 de 5')],
      );

      for (final String absent in <String>['±', 'sin rating']) {
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
      await pump(tester, accountEmail: 'ana@correo.mx');

      expect(find.byType(Aki), findsOneWidget);
      expect(find.textContaining('Cada día que juegas'), findsNothing);
    });
  });
}
