import 'package:akimath_app/design/theme.dart';
import 'package:akimath_app/design/widgets/baseline_meter.dart';
import 'package:akimath_app/design/widgets/icon_button_tile.dart';
import 'package:akimath_app/design/widgets/spec/mastery_level.dart';
import 'package:akimath_app/features/map/policy/skill_map.dart';
import 'package:akimath_app/features/map/ui/node_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const SkillNode _fractions = SkillNode(
  label: 'Cuentas',
  blurb: 'Sumar, restar y comparar.',
  level: MasteryLevel.inProgress,
  reachedStep: 3,
  topStep: 5,
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: AkiMathTheme.build(), home: Material(child: screen)),
  );
}

void main() {
  testWidgets('names the topic, what it asks, and the state it is in',
      (WidgetTester tester) async {
    await _pump(
      tester,
      NodeDetailScreen(node: _fractions, onBack: () {}),
    );

    expect(find.text('CUENTAS'), findsOneWidget);
    expect(find.text('Sumar, restar y comparar.'), findsOneWidget);
    expect(find.text('EN CURSO'), findsOneWidget);
  });

  testWidgets('prints the progress the ladder gives it, and no rating',
      (WidgetTester tester) async {
    await _pump(
      tester,
      NodeDetailScreen(node: _fractions, onBack: () {}),
    );

    expect(find.text('60%'), findsOneWidget);
    expect(find.textContaining('nivel 3 de 5'), findsOneWidget);
    // F4 has no rating and the server returns a null delta, so a figure here
    // would be one sync could later contradict.
    expect(find.textContaining('RATING'), findsNothing);
  });

  testWidgets('the meter shows no week-ago marker, because nothing records one',
      (WidgetTester tester) async {
    await _pump(
      tester,
      NodeDetailScreen(node: _fractions, onBack: () {}),
    );

    final BaselineMeter meter =
        tester.widget<BaselineMeter>(find.byType(BaselineMeter));
    expect(meter.baseline, isNull);
    expect(meter.fill, MasteryLevel.inProgress);
  });

  testWidgets('says which topic it comes from', (WidgetTester tester) async {
    await _pump(
      tester,
      NodeDetailScreen(
        node: _fractions,
        onBack: () {},
        previous: const SkillNode(
          label: 'Series',
          blurb: 'x',
          level: MasteryLevel.mastered,
          reachedStep: 4,
          topStep: 4,
        ),
      ),
    );

    expect(find.text('Viene de Series, que ya dominas.'), findsOneWidget);
  });

  testWidgets('the first topic on the map says so instead',
      (WidgetTester tester) async {
    await _pump(tester, NodeDetailScreen(node: _fractions, onBack: () {}));

    expect(find.text('Es por donde empieza el mapa.'), findsOneWidget);
  });

  testWidgets('offers practice only when a caller can start one',
      (WidgetTester tester) async {
    await _pump(tester, NodeDetailScreen(node: _fractions, onBack: () {}));
    expect(find.text('Practicar 5 retos'), findsNothing);

    int started = 0;
    await _pump(
      tester,
      NodeDetailScreen(
        node: _fractions,
        onBack: () {},
        onPractise: () => started++,
      ),
    );
    await tester.tap(find.text('Practicar 5 retos'));
    await tester.pump();

    expect(started, 1);
  });

  testWidgets('a locked topic offers no practice, whatever the caller passes',
      (WidgetTester tester) async {
    await _pump(
      tester,
      NodeDetailScreen(
        node: const SkillNode(
          label: 'Cuadros',
          blurb: 'x',
          level: MasteryLevel.locked,
          reachedStep: 0,
          topStep: 4,
        ),
        onBack: () {},
        onPractise: () {},
      ),
    );

    expect(find.text('BLOQUEADO'), findsOneWidget);
    expect(find.text('Practicar 5 retos'), findsNothing);
  });

  testWidgets('the way back is drawn twice and both work',
      (WidgetTester tester) async {
    int back = 0;
    await _pump(
      tester,
      NodeDetailScreen(node: _fractions, onBack: () => back++),
    );

    await tester.tap(find.text('Volver al mapa'));
    await tester.pump();
    expect(back, 1);

    await tester.tap(find.byType(IconButtonTile));
    await tester.pump();
    expect(back, 2);
  });
}
