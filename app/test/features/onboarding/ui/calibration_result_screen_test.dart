import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:akimath_app/features/onboarding/policy/calibration.dart';
import 'package:akimath_app/features/onboarding/ui/calibration_result_screen.dart';
import 'package:akimath_app/features/shell/ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const CalibrationOutcome _sixOfTen = CalibrationOutcome(
  asked: 10,
  answered: 6,
  correct: 4,
  elapsed: Duration(minutes: 2, seconds: 14),
);

Future<void> _pump(
  WidgetTester tester, {
  CalibrationOutcome outcome = _sixOfTen,
  VoidCallback? onEnter,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AkiMathTheme.build(),
      home: AppShell(
        child: CalibrationResultScreen(
          outcome: outcome,
          onEnter: onEnter ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _copyOn(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text text) => text.data ?? '')
    .where((String line) => line.isNotEmpty)
    .toList();

void main() {
  testWidgets('the figures it reports are the ones the device measured',
      (WidgetTester tester) async {
    await _pump(tester);

    expect(find.text(EsMxNumber.ratio(4, 6)), findsOneWidget);
    expect(find.text(EsMxNumber.elapsed(const Duration(minutes: 2, seconds: 14))),
        findsOneWidget);
  });

  testWidgets('a different probe reports different figures',
      (WidgetTester tester) async {
    // The control. Without it the two above pass for a screen that prints two
    // constants.
    await _pump(
      tester,
      outcome: const CalibrationOutcome(
        asked: 10,
        answered: 10,
        correct: 9,
        elapsed: Duration(minutes: 4, seconds: 5),
      ),
    );

    expect(find.text(EsMxNumber.ratio(9, 10)), findsOneWidget);
    expect(find.text('4:05'), findsOneWidget);
  });

  testWidgets('the rating card the design draws is absent, not blank',
      (WidgetTester tester) async {
    // `0.6` draws `RATING 1 248` under the headline and there is no rating
    // system to fill it: rating never runs in Dart, and `GET /me/standing`
    // answers one *per skill*, so no single number is a fact about a player.
    // It was an invented constant until 2026-09-02. Absent rather than a dash
    // or a zero (DR-P2) — a card with nothing in it promises a figure that has
    // no date on it.
    await _pump(tester);

    expect(find.textContaining('RATING'), findsNothing);
    expect(find.text('AQUÍ EMPIEZAS'), findsOneWidget);
  });

  testWidgets('and the two figures under it are still the measured ones',
      (WidgetTester tester) async {
    // The control for the assertion above: a screen that drew nothing at all
    // would satisfy it. `_sixOfTen` answered six of ten in 2:14, and both
    // figures came off the device.
    await _pump(tester);

    expect(find.text('ACIERTOS'), findsOneWidget);
    expect(find.text('TIEMPO'), findsOneWidget);
    expect(find.text(EsMxNumber.ratio(4, 6)), findsOneWidget);
  });

  testWidgets('and it says, in the design\'s words, that it is not a mark',
      (WidgetTester tester) async {
    await _pump(tester);

    expect(
      find.text(
        'No es calificación. Es de dónde salimos, y se mueve todos los días.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('it claims no level, no rank and no place on a ladder',
      (WidgetTester tester) async {
    // The one thing this screen must not do. A placement algorithm does not
    // exist, so any word that reads as one would be invented.
    await _pump(tester);

    final Iterable<String> copy =
        _copyOn(tester).map((String line) => line.toLowerCase());

    for (final String claim in <String>['nivel', 'rango', 'lugar', 'puesto']) {
      expect(
        copy.where((String line) => line.contains(claim)),
        isEmpty,
        reason: 'the result screen said "$claim"',
      );
    }
  });

  testWidgets('Aki is wagging, which is the design\'s fan',
      (WidgetTester tester) async {
    // Design decision D9: the document's `base` / `fan` / `error` are aliases
    // of the code's `base` / `correct` / `slip`.
    await _pump(tester);

    expect(tester.widget<Aki>(find.byType(Aki)).pose, AkiPose.correct);
  });

  testWidgets('the one button leaves for wherever the caller says',
      (WidgetTester tester) async {
    int entered = 0;
    await _pump(tester, onEnter: () => entered++);

    await tester.tap(find.text('Entrar a mi mapa'));
    await tester.pumpAndSettle();

    expect(entered, 1);
  });
}
