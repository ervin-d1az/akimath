import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/design/widgets/spec/verdict_copy.dart';
import 'package:akimath_app/design/widgets/verdict_ring.dart';
import 'package:akimath_app/features/preferences/ui/legend_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The verdict legend, on the screen it moved to.
///
/// It used to be a card on Ajustes-as-a-root. Ajustes is a stack now, and the
/// legend is what `Cómo se leen los retos` opens — these assertions are the
/// ones that came with it, unchanged in what they claim.
Future<void> pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: LegendScreen(onBack: () {}))),
  );
  await tester.pumpAndSettle();
}

List<String> copy(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => s.isNotEmpty)
    .toList();

void main() {
  testWidgets('shows both marks with what each means', (WidgetTester tester) async {
    // The words the screens themselves use, from `verdict_copy.dart`. The
    // legend used to say `Acierto` / `Se torció` while `03` and `04` said
    // `¡Bien hecho!` / `Casi` — a key to two terms the app never showed.
    await pump(tester);

    expect(find.text(verdictHeadline(Verdict.correct)), findsOneWidget);
    expect(find.text(verdictHeadline(Verdict.wrong)), findsOneWidget);
    expect(find.byType(VerdictRing), findsNWidgets(2));
  });

  testWidgets('the two differ by shape, not only by hue', (WidgetTester tester) async {
    // BRD-1, and the reason this screen earns its place: shown together the
    // difference is legible as a difference, which it never is one screen at a
    // time.
    await pump(tester);

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
    await pump(tester);
    final String all = copy(tester).join(' ').toLowerCase();

    for (final String forbidden in <String>[
      'incorrecto',
      'fallaste',
    ]) {
      expect(all, isNot(contains(forbidden)), reason: '"$forbidden" appeared');
    }
  });

  testWidgets('no toggle rode along with it', (WidgetTester tester) async {
    // `4.5` draws this preview under a `Modo daltonismo` switch whose own note
    // says the mode *"no cambia el diseño: solo lo hace obvio"* — the encoding
    // is always on (D6), so the switch has nothing to switch. A control that
    // does nothing is worse than an absent one.
    await pump(tester);

    expect(find.byType(Switch), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });
}
