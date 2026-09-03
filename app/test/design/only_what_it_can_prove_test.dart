/// No screen states a figure the product cannot produce.
///
/// **The rule already existed and nothing checked it.** `CLAUDE.md` records
/// that `03 Acierto` and `04 Error` show time and streak and **no rating**,
/// *"so nothing on them is a figure sync could later contradict"*, and that
/// `Perfil`'s rating slot is empty rather than averaged into existence because
/// `GET /me/standing` answers a rating **per skill** and no single number over
/// a list of Glicko ratings is a fact about a player. Three screens broke that
/// rule anyway, out of a quarantine file whose one switch was supposed to hold
/// it — and one of those three read the invented rating past the switch
/// entirely, so the switch could not have held it. A rule enforced by a
/// constant somebody has to remember to flip is a rule with no gate.
///
/// **What went red here, in production, in front of a real player**
/// (`2026-09-02`, first playthrough against the live API): two structurally
/// different series — one four of five, one from an issued pack, neither
/// containing a fraction or a multiplication — printed the byte-identical
/// `+ 12 RATING` and `QUÉ MEJORÓ · Fracciones 68 % · Multiplicar 96 %`.
///
/// **Rendered, not grepped.** A source scan sees the string; only a pumped tree
/// sees whether it reaches a screen, and a figure can arrive through a widget
/// that spells its own label. This walks the same registry the overflow, touch
/// and shadow gates walk, so a new screen is covered the day it is registered
/// and nobody has to declare it here.
///
/// Editing this file is the moment somebody is arguing that one of these
/// figures has become real. That argument belongs in the pull request that
/// makes it real, next to whatever now computes it — the same shape as the pin
/// that keeps `Ayuda` absent until there is somewhere for it to go.
library;

import 'dart:io';

import 'package:akimath_app/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_registry.dart';

/// The labels only an unprovable figure can sit under.
///
/// Each is checked as a **substring** of a rendered `Text`, not as an exact
/// match: `RATING POR TEMA` walks straight through an equality check, and the
/// eyebrow is what a screen would reach for either way.
///
/// The three are the three that shipped, and they are the whole of what this
/// half reads for. **A new invented figure under a new label is not covered**,
/// by construction: nothing forces one through `lib/demo/`, so
/// `const int _points = 1248;` drawn under `PUNTOS` from inside a screen would
/// pass both halves of this file. That is a known limit and it is written here
/// rather than papered over — the check below is a resurrection guard for one
/// deleted file, not a net over labels nobody has invented yet. Whoever adds a
/// figure adds its needle, and the reason this file is greppable at all is so
/// that reviewing a new one is a `grep` rather than a memory.
const Map<String, String> _cannotBeStated = <String, String>{
  'RATING': 'rating never runs in Dart, and the server answers one per skill',
  'QUÉ MEJORÓ': 'nothing tracks mastery per skill; the device never sees a '
      'skill_id and GET /me/history reports a session at a time',
  'QUÉ SIGUE': 'a recommendation needs GET /items/next, which answers 501',
};

/// The one registered screen allowed to print one of them, and why.
///
/// `perfil · cifras al máximo` is a **width probe, not a shipping state**: it
/// exists to measure `4.1`'s headline card at 390 px and `textScaler` 1.3
/// against the widest figure it could ever hold, and `ProfileFigures.rating` is
/// null from every caller in `lib/` — `headlineLead` falls back to `DÍAS`, which
/// is what a player sees. The registry entry says so itself. Excusing the
/// fixture keeps that measurement while the rule holds over every screen a
/// player can reach.
const Map<String, String> _excused = <String, String>{
  'perfil · cifras al máximo':
      'a layout fixture for a figure no caller passes; the shipping shape is '
          'perfil · solo lo comprobable, which draws DÍAS',
};

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = ScreenViewport.designPhone.physicalSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: AkiMathTheme.build(), home: screen),
  );
  await tester.pumpAndSettle();
}

List<String> _copyOn(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => s.isNotEmpty)
    .toList();

/// Walks up from this file until it finds the directory holding `pubspec.yaml`.
///
/// Not `../..` from the current directory: a runner invoked from the repository
/// root and one invoked from `app/` disagree about where that is, and a path
/// that resolves to nothing makes a scan vacuously green (PROC-9, PROC-10).
Directory _appRoot() {
  Directory here = File.fromUri(Platform.script).parent;
  if (!File('${here.path}/pubspec.yaml').existsSync()) {
    here = Directory.current;
  }
  while (!File('${here.path}/pubspec.yaml').existsSync()) {
    final Directory up = here.parent;
    if (up.path == here.path) {
      fail('no pubspec.yaml above ${Directory.current.path}');
    }
    here = up;
  }
  return here;
}

void main() {
  group('the harness', () {
    test('the registry it walks is not empty', () {
      // PROC-10. A gate whose input list reaches zero reports success for
      // finding nothing wrong, which is the one failure it cannot show.
      expect(registeredScreens, isNotEmpty);
    });

    test('every excused label names a screen that exists', () {
      // An excuse for a screen that was renamed protects nothing and hides the
      // rename. The same check `quiet_while_you_solve_test.dart` makes over its
      // list of solving surfaces.
      final Set<String> labels =
          registeredScreens.map((RegisteredScreen s) => s.label).toSet();

      expect(_excused.keys.where((String e) => !labels.contains(e)), isEmpty);
      for (final String reason in _excused.values) {
        expect(reason, isNotEmpty);
      }
    });

    testWidgets('the needles match the way a screen would print them',
        (WidgetTester tester) async {
      // The control. Without it the sweep below passes for a matcher that
      // matches nothing — and the excused screen is the one place in the tree
      // that still prints one of the three, so it is also the proof the sweep
      // can see them at all.
      final RegisteredScreen probe = registeredScreens
          .firstWhere((RegisteredScreen s) => s.label == 'perfil · cifras al máximo');

      await _pump(tester, probe.build());

      expect(
        _copyOn(tester).any((String s) => s.contains('RATING')),
        isTrue,
        reason: 'the width probe draws the card this gate reads for',
      );
    });
  });

  group('no screen states a figure the product cannot produce', () {
    for (final RegisteredScreen screen in registeredScreens
        .where((RegisteredScreen s) => !_excused.containsKey(s.label))) {
      testWidgets('${screen.label}: every figure on it has a source',
          (WidgetTester tester) async {
        await _pump(tester, screen.build());

        final List<String> copy = _copyOn(tester);
        for (final MapEntry<String, String> banned in _cannotBeStated.entries) {
          final Iterable<String> stated =
              copy.where((String s) => s.contains(banned.key));
          expect(
            stated,
            isEmpty,
            reason: '${screen.label} prints $stated — ${banned.value}',
          );
        }
      });
    }
  });

  group('the quarantine is gone rather than switched off', _quarantineIsGone);
}

/// `lib/demo/` held every invented figure behind one `enabled` constant.
///
/// It is deleted rather than set to false, on the argument `CLAUDE.md` already
/// makes about the pack generator that went the same way: *code nothing calls
/// is a claim about the product that is not true*. A `false` switch leaves
/// three render paths and five constants in the tree, each with a doc comment
/// describing a figure nobody draws, one flip away from shipping again — and
/// the flip was the thing that failed.
///
/// **This keeps that one file deleted, and claims nothing wider.** It cannot
/// see an invented figure written straight into a screen; only the needle sweep
/// above can, and only for a label it already knows.
void _quarantineIsGone() {
  test('no directory holds figures the product cannot compute', () {
    final Directory quarantine = Directory('${_appRoot().path}/lib/demo');

    expect(
      quarantine.existsSync(),
      isFalse,
      reason: 'lib/demo/ is back, and the quarantine it held is the shape '
          'that shipped an invented figure once already',
    );
  });

  test('and the root it looks in is really the app', () {
    // PROC-10 for a filesystem probe: a check for the absence of a path is
    // green when the path it built is nonsense, which is exactly the shape a
    // wrong root gives it.
    expect(File('${_appRoot().path}/lib/main.dart').existsSync(), isTrue);
  });
}
