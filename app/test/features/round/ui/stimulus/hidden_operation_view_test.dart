import 'package:akimath_app/design/widgets/candy_surface.dart';
import 'package:akimath_app/features/round/ui/stimulus/hidden_operation_view.dart';
import 'package:flutter/material.dart';
import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:flutter_test/flutter_test.dart';

/// The frozen golden: `2 › 7`, `5 › 16`, query 9. The rule is `×3 + 1`.
const List<({int input, int output})> _tripleAndOne =
    <({int input, int output})>[
  (input: 2, output: 7),
  (input: 5, output: 16),
];

Future<void> _pump(
  WidgetTester tester, {
  List<({int input, int output})> examples = _tripleAndOne,
  int queryInput = 9,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: HiddenOperationView(
              examples: examples,
              queryInput: queryInput,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('nothing between two numbers reads as arithmetic', () {
    testWidgets('the machine joins them with an arrow, not a chevron',
        (WidgetTester tester) async {
      // `2 › 4` is indistinguishable from `2 > 4`, which is false — and this is
      // the one screen where a player is being asked to read a relationship off
      // the numbers in front of them.
      await _pump(tester);

      // **Asked of the glyph, not of a character.** These lines used to read
      // `find.text('→')`, which was true of the stand-in and says nothing now
      // that a glyph is geometry. What has to hold is unchanged: the mark
      // between the two numbers is `mapsTo` — *becomes* — and never `forward`,
      // whose stand-in `›` set between numerals reads as `>`.
      expect(find.text('›'), findsNothing);
      expect(find.text('>'), findsNothing);

      final Iterable<BrandGlyph> bridges = tester
          .widgetList<BrandIcon>(find.byType(BrandIcon))
          .map((BrandIcon icon) => icon.glyph);
      expect(bridges, isNotEmpty);
      expect(bridges, everyElement(isNot(BrandGlyph.forward)));
      expect(bridges, contains(BrandGlyph.mapsTo));
    });
  });


  group('the machine shows its workings and one question', () {
    testWidgets('both examples are drawn whole', (WidgetTester tester) async {
      await _pump(tester);

      for (final String value in <String>['2', '7', '5', '16']) {
        expect(find.text(value), findsOneWidget, reason: value);
      }
    });

    testWidgets('the query has an input and a hole',
        (WidgetTester tester) async {
      await _pump(tester);

      expect(find.text('9'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
      // Two examples plus the query: three rows, two tiles each.
      expect(find.byType(CandySurface), findsNWidgets(6));
    });

    testWidgets('a third example makes a third row',
        (WidgetTester tester) async {
      await _pump(
        tester,
        examples: const <({int input, int output})>[
          (input: 1, output: 4),
          (input: 2, output: 7),
          (input: 3, output: 10),
        ],
      );

      expect(find.byType(CandySurface), findsNWidgets(8));
      expect(find.text('10'), findsOneWidget);
    });
  });

  group('the query is below the examples, not among them', () {
    testWidgets('the hole sits under every worked output',
        (WidgetTester tester) async {
      // The claim that makes it a question rather than a fourth example. A
      // layout that interleaved the query would still draw six tiles and still
      // find every value.
      await _pump(tester);

      final double hole = tester.getCenter(find.text('?')).dy;

      expect(tester.getCenter(find.text('7')).dy, lessThan(hole));
      expect(tester.getCenter(find.text('16')).dy, lessThan(hole));
      expect(tester.getCenter(find.text('9')).dy,
          moreOrLessEquals(hole, epsilon: 0.5),
          reason: 'the query input shares its row with the hole');
    });

    testWidgets('each example keeps its input beside its own output',
        (WidgetTester tester) async {
      // Transposing the rows would pair 2 with 16, which is a different — and
      // unsolvable — question.
      await _pump(tester);

      expect(tester.getCenter(find.text('2')).dy,
          moreOrLessEquals(tester.getCenter(find.text('7')).dy, epsilon: 0.5));
      expect(tester.getCenter(find.text('5')).dy,
          moreOrLessEquals(tester.getCenter(find.text('16')).dy, epsilon: 0.5));
      expect(tester.getCenter(find.text('2')).dx,
          lessThan(tester.getCenter(find.text('7')).dx));
    });
  });

  group('the hole is distinguishable without hue', () {
    testWidgets('exactly one tile is dashed', (WidgetTester tester) async {
      await _pump(tester);

      final List<CandySurface> tiles =
          tester.widgetList<CandySurface>(find.byType(CandySurface)).toList();
      final Iterable<CandySurface> dashed =
          tiles.where((CandySurface t) => t.borderDash != null);

      expect(dashed, hasLength(1));
      expect(dashed.single.background, isNot(tiles.first.background));
    });
  });

  group('Aki is not here', () {
    testWidgets('nothing in the machine draws her', (WidgetTester tester) async {
      // `CLAUDE.md`: she does not appear while the learner is solving. The
      // implementation plan sketches this family "with Aki's tail curl", so
      // this is the assertion that keeps the sketch from quietly winning.
      await _pump(tester);

      expect(find.bySemanticsLabel('Aki'), findsNothing);
    });
  });

  group('it survives real content', () {
    testWidgets('three-digit outputs still fit', (WidgetTester tester) async {
      await _pump(
        tester,
        examples: const <({int input, int output})>[
          (input: 10, output: 100),
          (input: 25, output: 250),
        ],
        queryInput: 40,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('250'), findsOneWidget);
    });
  });
}
