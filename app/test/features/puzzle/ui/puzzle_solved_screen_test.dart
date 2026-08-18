import 'package:akimath_app/design/widgets/stat_tile.dart';
import 'package:akimath_app/design/widgets/verdict_ring.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_solved_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  String format = 'Kakuro',
  Duration elapsed = const Duration(seconds: 92, milliseconds: 400),
  int streakDays = 5,
  VoidCallback? onDone,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: PuzzleSolvedScreen(
        format: format,
        elapsed: elapsed,
        streakDays: streakDays,
        onDone: onDone ?? () {},
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
  group('it says what was finished', () {
    testWidgets('the format is named', (WidgetTester tester) async {
      // Five formats are reachable from one home, so "you finished a puzzle"
      // does not tell a player which one they beat.
      await _pump(tester, format: 'Sopa de letras');
      expect(find.text('Sopa de letras'), findsOneWidget);
    });

    testWidgets('and it reads as finished, not as graded',
        (WidgetTester tester) async {
      await _pump(tester);
      final String all = _copy(tester).join(' ').toLowerCase();

      for (final String absent in <String>[
        'correcto',
        'incorrecto',
        'acierto',
        'error',
        'bien hecho',
      ]) {
        expect(all, isNot(contains(absent)), reason: '"$absent" appeared');
      }
    });
  });

  group('two figures, both the device\'s own', () {
    testWidgets('time and streak', (WidgetTester tester) async {
      await _pump(tester);

      expect(find.text('TIEMPO'), findsOneWidget);
      expect(find.text('RACHA'), findsOneWidget);
      expect(find.byType(StatTile), findsNWidgets(2));
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('no rating, accuracy or comparison',
        (WidgetTester tester) async {
      // F3 has no sync, so a figure here could be contradicted later — the
      // same reason the verdict screens carry two tiles and not three.
      await _pump(tester);
      final String all = _copy(tester).join(' ').toLowerCase();

      for (final String absent in <String>[
        'rating',
        'puntos',
        'precisión',
        'promedio',
        'récord',
        '%',
      ]) {
        expect(all, isNot(contains(absent)), reason: '"$absent" appeared');
      }
    });

    testWidgets('a long sitting reads as minutes, not as a pile of seconds',
        (WidgetTester tester) async {
      // The verdict screens print `4,2 s`, which is right for a reaction. An
      // hour of Kakuro in the same format is `3 849,0 s` — a number nobody can
      // take in, and one that overflows the tile at `textScaler` 1.3.
      await _pump(tester, elapsed: const Duration(minutes: 21, seconds: 7));

      expect(find.text('21:07'), findsOneWidget);
    });

    testWidgets('an hour still fits the shape', (WidgetTester tester) async {
      await _pump(tester, elapsed: const Duration(hours: 1, minutes: 4, seconds: 9));

      expect(find.text('64:09'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('one state carries no hue', () {
    testWidgets('there is no verdict mark', (WidgetTester tester) async {
      // BRD-1 asks that a *pair* be distinguishable by shape. A puzzle has no
      // wrong ending, so there is no pair and a ring here would be a mark with
      // nothing to contrast against.
      await _pump(tester);
      expect(find.byType(VerdictRing), findsNothing);
    });
  });

  group('the way on', () {
    testWidgets('one button, and it calls back', (WidgetTester tester) async {
      int done = 0;
      await _pump(tester, onDone: () => done++);

      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
      expect(done, 1);
    });
  });
}
