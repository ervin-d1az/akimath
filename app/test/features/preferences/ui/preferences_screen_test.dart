import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/design/widgets/spec/verdict_copy.dart';
import 'package:akimath_app/design/widgets/verdict_ring.dart';
import 'package:akimath_app/features/preferences/policy/erasure.dart';
import 'package:akimath_app/features/preferences/ui/preferences_screen.dart';
import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  String? accountEmail,
  AccountState accountState = AccountState.none,
  VoidCallback? onEraseData,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PreferencesScreen(
          accountEmail: accountEmail,
          accountState: accountState,
          onEraseData: onEraseData,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _copy(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => s.isNotEmpty)
    .toList();

void main() {
  group('it shows only what the device can compute', () {
    testWidgets('and the two figures it used to show are not here any more',
        (WidgetTester tester) async {
      // `TU PROGRESO` moved to `Avance` when that root landed. Ajustes is
      // settings; what a player has done is not a setting, and printing it in
      // two places is two places that can disagree.
      await _pump(tester);

      expect(find.text('TU PROGRESO'), findsNothing);
      expect(find.text('DÍAS'), findsNothing);
      expect(find.text('RACHA'), findsNothing);
    });

    testWidgets('no rating, accuracy, mean time or history',
        (WidgetTester tester) async {
      // `4.1 Perfil` prints all four and every one is the server's at F3. A
      // settings screen showing them would be printing figures nothing can
      // calculate — the same reason the verdict screens show no rating.
      await _pump(tester);
      final String all = _copy(tester).join(' ').toLowerCase();

      for (final String absent in <String>[
        'rating',
        'puntos',
        'precisión',
        'promedio',
        'historial',
        '%',
      ]) {
        expect(all, isNot(contains(absent)), reason: '"$absent" appeared');
      }
    });
  });

  group('the verdict legend', () {
    testWidgets('shows both marks with what each means',
        (WidgetTester tester) async {
      await _pump(tester);
      // The words the screens themselves use, from `verdict_copy.dart`. The
      // legend used to say `Acierto` / `Se torció` while `03` and `04` said
      // `¡Bien hecho!` / `Casi` — a key to two terms the app never showed.
      expect(find.text(verdictHeadline(Verdict.correct)), findsOneWidget);
      expect(find.text(verdictHeadline(Verdict.wrong)), findsOneWidget);
      expect(find.byType(VerdictRing), findsNWidgets(2));
    });

    testWidgets('the two differ by shape, not only by hue',
        (WidgetTester tester) async {
      // BRD-1, and the reason this card earns its place: shown together the
      // difference is legible as a difference, which it never is one screen at
      // a time.
      await _pump(tester);

      final List<Verdict> verdicts = tester
          .widgetList<VerdictRing>(find.byType(VerdictRing))
          .map((VerdictRing r) => r.verdict)
          .toList();

      expect(
        verdicts.map((Verdict v) => v.outline).toSet(),
        <VerdictOutline>{VerdictOutline.solid, VerdictOutline.dashed},
        reason: 'both outlines must appear, or the pair reads by hue alone',
      );
    });

    testWidgets('the copy does not scold', (WidgetTester tester) async {
      await _pump(tester);
      final String all = _copy(tester).join(' ').toLowerCase();

      for (final String forbidden in <String>[
        'incorrecto',
        'error',
        'fallaste',
        'mal',
      ]) {
        expect(all, isNot(contains(forbidden)), reason: '"$forbidden" appeared');
      }
    });
  });

  group('a control with no effect is not drawn', () {
    testWidgets('none of the four deferred toggles appears',
        (WidgetTester tester) async {
      // `Reducir movimiento` acquires an effect at F8; text size and high
      // contrast have no specification; colour-blind mode would change nothing
      // while shape already carries every verdict (DR-P2). A switch that does
      // nothing is worse than an absent one.
      await _pump(tester);

      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);

      final String all = _copy(tester).join(' ').toLowerCase();
      for (final String absent in <String>[
        'reducir movimiento',
        'tamaño de texto',
        'alto contraste',
        'daltonismo',
      ]) {
        expect(all, isNot(contains(absent)), reason: '"$absent" appeared');
      }
    });
  });

  group('the door out of an account', () {
    testWidgets('is drawn where a session could carry the request',
        (WidgetTester tester) async {
      await _pump(
        tester,
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.linked,
        onEraseData: () {},
      );

      expect(find.text(erasureDoorLabel), findsOneWidget);
    });

    testWidgets('and is absent rather than dead when it could only fail',
        (WidgetTester tester) async {
      // The route decides that — `erasureOffered` — and hands null. A control
      // that can only produce an error is worse than no control (DR-P2), which
      // is the same reading that keeps every toggle off this screen.
      await _pump(
        tester,
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.rejected,
      );

      expect(find.text(erasureDoorLabel), findsNothing);
    });

    testWidgets('pressing it asks the caller, and asks nothing itself',
        (WidgetTester tester) async {
      // No dialog from here. The question is a screen of its own, because it
      // has to fit a sentence about what survives, and a Material dialog is not
      // a surface this app draws.
      int opened = 0;
      await _pump(
        tester,
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.linked,
        onEraseData: () => opened++,
      );

      await tester.tap(find.text(erasureDoorLabel));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });
  });
}
