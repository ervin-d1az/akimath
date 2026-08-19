import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/design/widgets/spec/verdict_copy.dart';
import 'package:akimath_app/design/widgets/verdict_ring.dart';
import 'package:akimath_app/features/preferences/ui/preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  int daysPractised = 12,
  int streakDays = 5,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PreferencesScreen(
          daysPractised: daysPractised,
          streakDays: streakDays,
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
    testWidgets('days practised and the streak', (WidgetTester tester) async {
      await _pump(tester);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('a player who has never played still gets a screen',
        (WidgetTester tester) async {
      // Zero, not a dash and not an empty space. There is no state in which
      // this screen has nothing to say, which is why it needs no skeleton.
      await _pump(tester, daysPractised: 0, streakDays: 0);
      expect(find.text('0'), findsNWidgets(2));
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
}
