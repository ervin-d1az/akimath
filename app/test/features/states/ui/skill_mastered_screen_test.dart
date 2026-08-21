import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/features/states/ui/skill_mastered_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(textDirection: TextDirection.ltr, child: screen),
  );
}

SkillMasteredScreen mastered({
  List<String> unlocked = const <String>['Porcentajes', 'Decimales'],
  VoidCallback? onOpenMap,
  VoidCallback? onContinue,
}) => SkillMasteredScreen(
  skillName: 'Fracciones',
  weekAgoPercent: 88,
  unlockedTopics: unlocked,
  onOpenMap: onOpenMap ?? () {},
  onContinue: onContinue ?? () {},
);

void main() {
  group('4.14 Habilidad dominada', () {
    testWidgets('names the skill in the headline and in the card', (
      WidgetTester tester,
    ) async {
      await pump(tester, mastered());

      expect(find.text('FRACCIONES,'), findsOneWidget);
      expect(find.text('DOMINADA'), findsOneWidget);
      expect(find.text('Fracciones'), findsOneWidget);
      // Spelled by the app's one percent speller, which sets the es-MX space
      // before the sign. The mutation this kills is a hardcoded '100%'.
      expect(find.text(EsMxNumber.percent(100)), findsOneWidget);
      expect(find.text('100%'), findsNothing);
      expect(
        find.text('La línea marca dónde estabas hace una semana'),
        findsOneWidget,
      );
    });

    testWidgets('lists what opened', (WidgetTester tester) async {
      await pump(tester, mastered());

      expect(find.text('SE ABRIERON DOS TEMAS'), findsOneWidget);
      expect(find.text('Porcentajes'), findsOneWidget);
      expect(find.text('Decimales'), findsOneWidget);
    });

    // No level, no rating, no points — none of it exists. Mastery is drawn as
    // a completed skill and nothing else.
    testWidgets('prints no rating and no level', (WidgetTester tester) async {
      await pump(tester, mastered());

      expect(find.textContaining('rating'), findsNothing);
      expect(find.textContaining('Rating'), findsNothing);
      expect(find.textContaining('nivel'), findsNothing);
      expect(find.textContaining('Nivel'), findsNothing);
    });

    // The design asks for a `fan` pose and only three exist. `correct` is the
    // celebratory one, and a fourth would be new geometry in the brand spec.
    testWidgets('Aki celebrates rather than resting', (
      WidgetTester tester,
    ) async {
      await pump(tester, mastered());

      final Aki aki = tester.widget<Aki>(find.byType(Aki));
      expect(aki.pose, AkiPose.correct);
    });

    testWidgets('both ways out do what they say', (WidgetTester tester) async {
      int map = 0;
      int carried = 0;
      await pump(
        tester,
        mastered(onOpenMap: () => map++, onContinue: () => carried++),
      );

      await tester.tap(find.text('Ver mi mapa'));
      await tester.pump();
      await tester.tap(find.text('Seguir con porcentajes'));
      await tester.pump();

      expect(map, 1);
      expect(carried, 1);
    });

    // A mastery that opened nothing is a real outcome — the panel goes rather
    // than announcing an empty list.
    testWidgets('no panel when nothing opened', (WidgetTester tester) async {
      await pump(tester, mastered(unlocked: const <String>[]));

      expect(find.textContaining('SE ABRI'), findsNothing);
      expect(find.text('Seguir con porcentajes'), findsNothing);
    });
  });
}
