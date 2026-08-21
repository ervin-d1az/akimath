import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_registry.dart';

/// Nothing watches you while you work: not the dog, not a clock.
///
/// Two rules from `CLAUDE.md`, in one file because they are one idea and they
/// fail the same way — an empty corner somebody decides to warm up.
///
/// **Aki does not appear while you are solving.**
///
/// It is one of three rules about her in `CLAUDE.md` and the only one about
/// *where* she is. The reasoning behind it is the whole character: a dog
/// watching over your shoulder while you work is a dog you are performing for.
/// She turns up when the answer is in — right or wrong — and on the screens
/// that are not a challenge at all.
///
/// **The rule was written down and nothing checked it.** Every solving surface
/// today happens to be clean; this is what keeps the next one clean, on the
/// afternoon somebody decides an empty corner needs warming up.
///
/// The one exception is `character sheet`, which is the internal reference
/// screen: it exists to show every pose side by side and is not a surface any
/// player reaches.
const List<String> _solvingSurfaces = <String>[
  // The item, in every family it can be drawn in.
  'round',
  // `0.3 Primer reto` — a fixed teaching item, and still an item.
  'first item',
  // `0.5 Calibración reactivo`. The design draws a 52px Aki in its header,
  // beside the skip control; this rule is why she is not there. A probe is
  // still solving, and the strip that says how many are left is the one
  // number a solving surface may show.
  'calibración · reactivo',
  // Every board, including the sopa de letras. `puzzle · solved` is not one:
  // the solving is over, which is exactly when she is allowed.
  'puzzle · kenken',
  'puzzle · killer',
  'puzzle · magic square',
  'puzzle · kakuro',
  'puzzle · word search',
];

bool _isSolving(String label) =>
    _solvingSurfaces.any((String prefix) => label.startsWith(prefix));

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = ScreenViewport.designPhone.physicalSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(theme: AkiMathTheme.build(), home: screen));
  await tester.pumpAndSettle();
}

Finder _anyAki() => find.byWidgetPredicate(
      (Widget w) => w is Aki || w is AkiFace,
      description: 'Aki, in any form',
    );

void main() {
  group('the harness', () {
    test('every named surface matches a registered screen', () {
      // PROC-10. A prefix that matches nothing excuses nothing and protects
      // nothing, and a screen renamed out from under this list would take its
      // rule with it silently.
      for (final String prefix in _solvingSurfaces) {
        expect(
          registeredScreens.any((RegisteredScreen s) => s.label.startsWith(prefix)),
          isTrue,
          reason: 'no registered screen starts with "$prefix"',
        );
      }
      final int solving = registeredScreens.where((RegisteredScreen s) => _isSolving(s.label)).length;
      expect(solving, greaterThan(0));
      // ignore: avoid_print
      print('  aki presence · ${registeredScreens.length} screens, '
          '$solving of them a solving surface');
    });

    testWidgets('and the finder finds her when she is there',
        (WidgetTester tester) async {
      // The control. Without it, "she is not on the round screen" passes for a
      // predicate that matches nothing anywhere.
      await _pump(tester, Center(child: Aki(width: 100)));
      expect(_anyAki(), findsOneWidget);

      await _pump(tester, Center(child: AkiFace(width: 100)));
      expect(_anyAki(), findsOneWidget);

      await _pump(tester, const SizedBox());
      expect(_anyAki(), findsNothing);
    });
  });

  group('while you are solving', () {
    for (final RegisteredScreen screen
        in registeredScreens.where((RegisteredScreen s) => _isSolving(s.label))) {
      testWidgets('${screen.label}: she is not there', (WidgetTester tester) async {
        await _pump(tester, screen.build());
        expect(_anyAki(), findsNothing);
      });
    }
  });

  group('and once the answer is in', () {
    // The other half. A rule that only ever says "absent" would be satisfied by
    // deleting her from the app.
    for (final String label in <String>['verdict · acierto', 'verdict · error', 'series summary']) {
      testWidgets('$label: she is', (WidgetTester tester) async {
        final RegisteredScreen screen = registeredScreens
            .firstWhere((RegisteredScreen s) => s.label == label);

        await _pump(tester, screen.build());

        expect(_anyAki(), findsWidgets);
      });
    }

    testWidgets('and a wrong answer is the pose whose curl has come undone',
        (WidgetTester tester) async {
      // The one body part that can be lost and come back. `AkiPose.slip` is
      // drawn nowhere else in the product — the character sheet is an internal
      // reference — so if the error screen stopped using it, the whole idea
      // would be artwork nobody ever sees.
      final RegisteredScreen error = registeredScreens
          .firstWhere((RegisteredScreen s) => s.label == 'verdict · error');

      await _pump(tester, error.build());

      final Aki drawn = tester.widget<Aki>(find.byType(Aki));
      expect(drawn.pose, AkiPose.slip);
    });

    testWidgets('and a right one is the pose that is wagging', (WidgetTester tester) async {
      final RegisteredScreen right = registeredScreens
          .firstWhere((RegisteredScreen s) => s.label == 'verdict · acierto');

      await _pump(tester, right.build());

      expect(tester.widget<Aki>(find.byType(Aki)).pose, AkiPose.correct);
    });
  });

  group('and there is no visible timer', () {
    /// Anything that reads as a clock running.
    ///
    /// `EsMxNumber.elapsed` prints `1:07` and `EsMxNumber.seconds` prints
    /// `4,2 s`; both are legitimate *after* the answer and neither may appear
    /// while it is being worked out. Matching the shapes rather than calling
    /// the formatters keeps the gate honest about a third spelling somebody
    /// writes by hand.
    final RegExp clock = RegExp(r'\b\d+:[0-5]\d\b|\b\d+([.,]\d+)?\s*(s|seg|segundos|min)\b');

    List<String> copyOn(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((Text t) => t.data ?? '')
        .where((String s) => s.isNotEmpty)
        .toList();

    test('the pattern matches what the app actually prints', () {
      // The control for the sweep below, over the two formatters that exist.
      expect(EsMxNumber.elapsed(const Duration(seconds: 67)), matches(clock));
      expect(EsMxNumber.seconds(4.2, places: 1), matches(clock));
      // And not over ordinary copy, or the gate would fire on every screen.
      for (final String innocent in <String>['Restas', '4/5', '19 ago', 'Siguiente', '12']) {
        expect(clock.hasMatch(innocent), isFalse, reason: innocent);
      }
    });

    for (final RegisteredScreen screen
        in registeredScreens.where((RegisteredScreen s) => _isSolving(s.label))) {
      testWidgets('${screen.label}: nothing on it is counting',
          (WidgetTester tester) async {
        // "No visible timer. Time is measured quietly." A clock on a challenge
        // turns a challenge into a test, which is a different product.
        await _pump(tester, screen.build());

        final List<String> ticking =
            copyOn(tester).where(clock.hasMatch).toList();
        expect(ticking, isEmpty, reason: '${screen.label} shows $ticking');
      });
    }

    testWidgets('but the verdict screen may say how long it took',
        (WidgetTester tester) async {
      // The other half. A rule that only ever says "absent" is satisfied by an
      // app that never measures anything.
      final RegisteredScreen right = registeredScreens
          .firstWhere((RegisteredScreen s) => s.label == 'verdict · acierto');

      await _pump(tester, right.build());

      expect(copyOn(tester).any(clock.hasMatch), isTrue);
    });
  });
}
