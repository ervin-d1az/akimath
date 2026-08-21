import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/design/painting/spec/dash_spec.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:akimath_app/design/widgets/candy_surface.dart';
import 'package:akimath_app/design/widgets/spec/mastery_level.dart';
import 'package:akimath_app/features/map/policy/skill_map.dart';
import 'package:akimath_app/features/map/ui/skill_map_screen.dart';
import 'package:akimath_app/features/map/ui/skill_node_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SkillNode _node(
  String label,
  MasteryLevel level, {
  int reached = 2,
  int top = 4,
}) =>
    SkillNode(
      label: label,
      blurb: 'Lo que pide $label.',
      level: level,
      reachedStep: level == MasteryLevel.available || level == MasteryLevel.locked
          ? 0
          : reached,
      topStep: top,
    );

SkillMap _map({int? focusIndex = 1}) => SkillMap(
      nodes: <SkillNode>[
        _node('Cuentas', MasteryLevel.mastered, reached: 4),
        _node('Series', MasteryLevel.inProgress),
        _node('Figuras', MasteryLevel.available),
        _node('Cuadros', MasteryLevel.locked),
      ],
      focusIndex: focusIndex,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: AkiMathTheme.build(), home: Material(child: screen)),
  );
}

void main() {
  testWidgets('draws one node per topic the pack carries', (WidgetTester tester) async {
    await _pump(tester, SkillMapScreen(map: _map(), onOpen: (int _) {}));

    expect(find.byType(SkillNodeTile), findsNWidgets(4));
    for (final String label in <String>['Cuentas', 'Series', 'Figuras', 'Cuadros']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('the topic the player meets next is the largest on the map',
      (WidgetTester tester) async {
    await _pump(tester, SkillMapScreen(map: _map(), onOpen: (int _) {}));

    final Size focused = tester.getSize(
      find.ancestor(
        of: find.text('Series'),
        matching: find.byType(SkillNodeTile),
      ),
    );
    final Size ordinary = tester.getSize(
      find.ancestor(
        of: find.text('Cuentas'),
        matching: find.byType(SkillNodeTile),
      ),
    );

    expect(focused.width, greaterThan(ordinary.width));
    expect(focused.height, greaterThan(ordinary.height));
  });

  testWidgets('a finished topic carries the check and a locked one the padlock',
      (WidgetTester tester) async {
    await _pump(tester, SkillMapScreen(map: _map(), onOpen: (int _) {}));

    Finder glyphIn(String label) => find.descendant(
          of: find.ancestor(
            of: find.text(label),
            matching: find.byType(SkillNodeTile),
          ),
          matching: find.byType(BrandIcon),
        );

    expect(tester.widget<BrandIcon>(glyphIn('Cuentas')).glyph, BrandGlyph.check);
    expect(tester.widget<BrandIcon>(glyphIn('Cuadros')).glyph, BrandGlyph.padlock);
  });

  testWidgets('a topic under way prints how far up the ladder it is',
      (WidgetTester tester) async {
    await _pump(tester, SkillMapScreen(map: _map(), onOpen: (int _) {}));

    // 2 of 4 steps.
    expect(find.text('50%'), findsWidgets);
  });

  testWidgets('opening a topic hands the node back', (WidgetTester tester) async {
    final List<String> opened = <String>[];
    await _pump(
      tester,
      SkillMapScreen(
        map: _map(),
        onOpen: (int index) => opened.add(_map().nodes[index].label),
      ),
    );

    await tester.tap(find.text('Cuentas'));
    await tester.pump();

    expect(opened, <String>['Cuentas']);
  });

  testWidgets('a locked topic is inert, because there is nothing to say yet',
      (WidgetTester tester) async {
    final List<String> opened = <String>[];
    await _pump(
      tester,
      SkillMapScreen(
        map: _map(),
        onOpen: (int index) => opened.add(_map().nodes[index].label),
      ),
    );

    await tester.tap(find.text('Cuadros'), warnIfMissed: false);
    await tester.pump();

    expect(opened, isEmpty);
  });

  testWidgets('the legend names all four states, including the fourth the '
      'design draws and never names', (WidgetTester tester) async {
    await _pump(tester, SkillMapScreen(map: _map(), onOpen: (int _) {}));

    for (final String state in <String>[
      'Dominado',
      'En curso',
      'Disponible',
      'Bloqueado',
    ]) {
      expect(find.text(state), findsOneWidget);
    }
  });

  testWidgets("the locked legend swatch reads as a dashed square, not as two "
      'arcs', (WidgetTester tester) async {
    // **Measured on an iPhone 17.** The swatch is 14 px across and carried
    // `DashSpec.locked`, whose 9-on/9-off period is 18 — nearly half the
    // outline's whole 39 px. Three dashes landed on the corners and the fourth
    // legend entry rendered as a broken curl beside three clean squares.
    //
    // The rule this pins: an outline has four sides, and a pattern must repeat
    // at least twice along one of them before it reads as a dash rather than as
    // a stroke that stopped. The mutation it catches is handing the swatch
    // `DashSpec.locked` again.
    await _pump(tester, SkillMapScreen(map: _map(), onOpen: (int _) {}));

    final Finder swatch = find.descendant(
      of: find
          .ancestor(of: find.text('Bloqueado'), matching: find.byType(Row))
          .first,
      matching: find.byType(CandySurface),
    );
    final DashSpec dash = tester.widget<CandySurface>(swatch).borderDash!;
    final double side = tester.getSize(swatch).width;

    expect(
      dash.on + dash.off,
      lessThanOrEqualTo(side / 2),
      reason: 'a ${dash.on}+${dash.off} period on a ${side}px side draws arcs',
    );
  });

  testWidgets('the counter says how many topics are under way',
      (WidgetTester tester) async {
    // Two of the four nodes have been met; the available and locked ones
    // have not.
    await _pump(tester, SkillMapScreen(map: _map(), onOpen: (int _) {}));

    expect(find.text('2 / 4'), findsOneWidget);
  });

  testWidgets('a pack with no topics says so rather than drawing an empty grid',
      (WidgetTester tester) async {
    await _pump(
      tester,
      SkillMapScreen(
        map: const SkillMap(nodes: <SkillNode>[], focusIndex: null),
        onOpen: (int _) {},
      ),
    );

    expect(find.byType(SkillNodeTile), findsNothing);
    expect(find.textContaining('paquete'), findsOneWidget);
  });
}
