import 'dart:convert';

import 'package:akimath_app/content/model/pack.dart';
import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/data/series_cursor_store.dart';
import 'package:akimath_app/features/home/policy/day_log.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/home/policy/puzzle_menu.dart';
import 'package:akimath_app/features/home/policy/puzzle_of_day.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_board_view.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_screen.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_solved_screen.dart';
import 'package:akimath_app/features/puzzle/ui/word_search_screen.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
import 'package:akimath_app/features/round/ui/summary/series_summary_screen.dart';
import 'package:akimath_app/features/round/ui/verdict/verdict_screen.dart';
import 'package:akimath_app/design/widgets/verdict_ring.dart';
import 'package:akimath_app/features/shell/ui/skeleton_block.dart';
import 'package:akimath_app/design/widgets/icon_button_tile.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/design/widgets/loading_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.source, {this.delay = Duration.zero});

  final String source;
  final Duration delay;

  @override
  Future<ByteData> load(String key) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return ByteData.sublistView(utf8.encode(source));
  }
}

const String _pack = '''
{
  "pack_version": 1,
  "pack_id": "test",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "2099-01-01T00:00:00Z",
  "misconceptions": {
    "no_specific_diagnosis": {
      "steps": ["Lee otra vez el reto, sin prisa."],
      "explain": "Repasa el reto con calma."
    }
  },
  "items": [
    {
      "id": "a1",
      "ladder_step": 2,
      "answer": "42",
      "prompt": [
        {"kind": "text", "value": "6"},
        {"kind": "operator", "glyph": "×"},
        {"kind": "text", "value": "7"},
        {"kind": "operator", "glyph": "="}
      ]
    }
  ]
}
''';

/// Two items whose prompts are told apart at a glance.
///
/// One item cannot show the defect this pack exists for: the preview and the
/// plan agree trivially when the pack holds a single item, whatever the cursor.
const String _twoItemPack = '''
{
  "pack_version": 1,
  "pack_id": "test",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "2099-01-01T00:00:00Z",
  "misconceptions": {
    "no_specific_diagnosis": {
      "steps": ["Lee otra vez el reto, sin prisa."],
      "explain": "Repasa el reto con calma."
    }
  },
  "items": [
    {
      "id": "a1",
      "ladder_step": 2,
      "answer": "42",
      "prompt": [
        {"kind": "text", "value": "6"},
        {"kind": "operator", "glyph": "×"},
        {"kind": "text", "value": "7"},
        {"kind": "operator", "glyph": "="}
      ]
    },
    {
      "id": "b2",
      "ladder_step": 2,
      "answer": "17",
      "prompt": [
        {"kind": "text", "value": "8"},
        {"kind": "operator", "glyph": "+"},
        {"kind": "text", "value": "9"},
        {"kind": "operator", "glyph": "="}
      ]
    }
  ]
}
''';

/// The same pack with two puzzles: one of each screen.
///
/// A hand-written pack rather than the shipped asset, because these tests are
/// about *recording* and not about what ships — and `rootBundle` is a global
/// whose cache outlives a test, which is a dependency worth not having.
const String _puzzlePack = '''
{
  "pack_version": 1,
  "pack_id": "test",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "2099-01-01T00:00:00Z",
  "misconceptions": {
    "no_specific_diagnosis": {
      "steps": ["Lee otra vez el reto, sin prisa."],
      "explain": "Repasa el reto con calma."
    }
  },
  "items": [
    {
      "id": "a1",
      "ladder_step": 2,
      "answer": "42",
      "prompt": [
        {"kind": "text", "value": "6"},
        {"kind": "operator", "glyph": "×"},
        {"kind": "text", "value": "7"},
        {"kind": "operator", "glyph": "="}
      ]
    }
  ],
  "puzzles": [
    {
      "kind": "kenken",
      "payload": {
        "board": {
          "size": 3,
          "blocked": [],
          "given": [],
          "solution": [[1, 2, 3], [2, 3, 1], [3, 1, 2]]
        },
        "cages": [
          {
            "cells": [
              {"row": 0, "col": 0}, {"row": 0, "col": 1}, {"row": 0, "col": 2},
              {"row": 1, "col": 0}, {"row": 1, "col": 1}, {"row": 1, "col": 2},
              {"row": 2, "col": 0}, {"row": 2, "col": 1}, {"row": 2, "col": 2}
            ],
            "operation": "+",
            "target": 18
          }
        ]
      },
      "tutorial_steps": ["Cada fila lleva 1, 2 y 3."],
      "reference_sheet": ["No se repite en su fila ni en su columna."]
    },
    {
      "kind": "wordSearch",
      "payload": {
        "grid": [
          ["S", "U", "M", "A"],
          ["C", "Y", "Z", "W"],
          ["E", "D", "F", "G"],
          ["R", "H", "I", "J"],
          ["O", "K", "L", "N"]
        ],
        "words": ["SUMA", "CERO"]
      },
      "tutorial_steps": ["Arrastra de la primera letra a la última."],
      "reference_sheet": ["Las palabras van en ocho direcciones."]
    }
  ]
}
''';

Future<void> _pump(
  WidgetTester tester, {
  String source = _pack,
  Duration delay = Duration.zero,
  DayLogStore? dayLog,
  RootVisibility visibility = RootVisibility.showing,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await _pumpAgain(
    tester,
    source: source,
    delay: delay,
    dayLog: dayLog,
    visibility: visibility,
  );
}

/// The same tree again, so `didUpdateWidget` runs on the state already there.
Future<void> _pumpAgain(
  WidgetTester tester, {
  String source = _pack,
  Duration delay = Duration.zero,
  DayLogStore? dayLog,
  RootVisibility visibility = RootVisibility.showing,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomeRoute(
        reader: PackReader(bundle: _FakeBundle(source, delay: delay)),
        now: () => DateTime(2026, 8, 16),
        dayLog: dayLog,
        visibility: visibility,
      ),
    ),
  );
}

/// Every puzzle the shipped pack carries, opened from the home for real.
///
/// **The gate the `pack.puzzles.first` defect walked past.** Four of the five
/// shipped formats were unreachable and every suite was green, because nothing
/// asked the question this asks: not "does the screen render" but "can a player
/// get to it". It reports a count and fails at zero (PROC-10), so a pack that
/// stopped carrying puzzles could not make it vacuously true.
Future<void> _reachEveryPuzzle(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final DateTime today = DateTime(2026, 8, 16);
  final Pack pack = await PackReader().load();
  expect(pack.puzzles, isNotEmpty, reason: 'the shipped pack carries no puzzle');

  // **The cards the home actually draws**, which is one per format rather than
  // one per board. That every *board* is offered on some day is a different
  // question, and `pack_variety_test` answers it over a fortnight — walking all
  // eleven here would open the same four screens eleven times and call it
  // coverage.
  final List<Puzzle> offered = puzzlesOfDay(pack.puzzles, today: today);
  expect(
    offered.map(puzzleKindOf).toSet(),
    pack.puzzles.map(puzzleKindOf).toSet(),
    reason: 'a format the pack carries reaches no card',
  );

  await tester.pumpWidget(
    MaterialApp(home: HomeRoute(now: () => today)),
  );
  await tester.pumpAndSettle();

  final Set<String> reached = <String>{};
  for (final Puzzle puzzle in offered) {
    final String label = puzzleName(puzzle);
    final Finder card = find.text(label);
    await tester.scrollUntilVisible(card, 120);
    await tester.tap(card);
    await tester.pumpAndSettle();

    // A word search takes letters and every other format takes digits, so the
    // two are different screens and picking the wrong one is a real mistake a
    // `findsWidgets`-style assertion would miss.
    final Type screen =
        puzzle is WordSearchPuzzle ? WordSearchScreen : PuzzleScreen;
    expect(
      find.byType(screen),
      findsOneWidget,
      reason: '"$label" did not open its screen',
    );
    reached.add(puzzle.runtimeType.toString());

    await tester.tap(find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.label == 'Salir',
    ));
    await tester.pumpAndSettle();
    expect(find.text('ROMPECABEZAS'), findsOneWidget,
        reason: 'leaving "$label" did not come back to the home');
  }

  // ignore: avoid_print
  print('  puzzle reachability · ${pack.puzzles.length} boards, '
      '${offered.length} offered today → ${reached.length} kinds reachable');
}

void main() {
  setUp(() {
    // The app's default store is the real `PrefsDayLogStore`, so these tests
    // exercise the real wiring rather than a substitute — over an in-memory
    // backend, which is what makes that possible without a device.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('the home loads its pack', () {
    testWidgets('a valid pack reaches the home', (WidgetTester tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('RETO DEL DÍA'), findsOneWidget);
    });

    testWidgets('the streak comes from the days it was given',
        (WidgetTester tester) async {
      await _pump(
        tester,
        dayLog: InMemoryDayLogStore(
          DayLog.empty
              .recording(DateTime(2026, 8, 15))
              .recording(DateTime(2026, 8, 16)),
        ),
      );
      await tester.pumpAndSettle();

      // The streak is labelled now, so the assertion names the label as well as
      // the figure — a bare `2` could be a day mark, a ladder step or anything
      // else the screen happens to print.
      expect(find.text('2 DÍAS'), findsOneWidget);
    });

    testWidgets('an expired pack is refused', (WidgetTester tester) async {
      await _pump(
        tester,
        source: _pack.replaceAll('2099-01-01', '2020-01-01'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsNothing);
      expect(find.textContaining('vencieron'), findsOneWidget);
    });

    testWidgets('a broken pack shows a message rather than crashing',
        (WidgetTester tester) async {
      await _pump(tester, source: '{"nope": true}');
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsNothing);
      expect(find.textContaining('No se pudo'), findsOneWidget);
    });
  });

  group('the card previews the series it is about to serve', () {
    testWidgets('a cursor past the first item carries the preview with it',
        (WidgetTester tester) async {
      // **The defect this records.** `preview` was `pack.items.first` — the
      // same expression on every launch, for ever — while `todaysFamilies` and
      // `_startSeries` both read the plan from the cursor. So the card promised
      // `6 × 7` and the series it started opened on `8 + 9`, on one screen, in
      // ten lines of each other.
      await const SeriesCursorStore().advance(1);

      await _pump(tester, source: _twoItemPack);
      await tester.pumpAndSettle();

      expect(
        tester.widget<HomeScreen>(find.byType(HomeScreen)).preview.id,
        'b2',
        reason: 'the card previewed the pack rather than the plan',
      );

      // The half that makes it a fact about the player rather than about one
      // expression: the series has to open on what the card promised.
      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<RoundScreen>(find.byType(RoundScreen)).items.first.id,
        'b2',
        reason: 'the card promised an item the series did not open with',
      );
    });

    testWidgets('a player who has been served nothing sees the first item',
        (WidgetTester tester) async {
      // The other direction, so "follow the plan" cannot be satisfied by any
      // fixed position in it.
      await _pump(tester, source: _twoItemPack);
      await tester.pumpAndSettle();

      expect(
        tester.widget<HomeScreen>(find.byType(HomeScreen)).preview.id,
        'a1',
      );
    });
  });

  group('loading is skeletal', () {
    testWidgets('the wait shows skeletons and no spinner',
        (WidgetTester tester) async {
      await _pump(tester, delay: const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.byType(SkeletonBlock), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LoadingDots), findsNothing);

      // pumpAndSettle waits for frames, not for a pending timer, so the delay
      // has to be advanced explicitly.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonBlock), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('starting a series is a full-screen session', () {
    testWidgets('the round is pushed over the home',
        (WidgetTester tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      // Declared rule 1: the series takes the whole screen. The home is still
      // mounted underneath, so the assertion is that it is not visible.
      expect(find.byType(RoundScreen), findsOneWidget);
      expect(find.byType(Keypad), findsOneWidget);
      expect(find.text('RETO DEL DÍA'), findsNothing);
    });

    testWidgets('a player can leave the session by tapping its close control',
        (WidgetTester tester) async {
      // **The earlier version of this test called `Navigator.pop` directly.**
      // That proved the *route* was poppable; it never proved a *player* could
      // pop it — and on iOS they could not. A `fullscreenDialog` route gets no
      // edge-swipe back gesture, iOS has no system back button, the round
      // cycles items forever, and there was no close control anywhere. A child
      // who tapped "Empezar la serie" could not reach the home again without
      // killing the app. Android hid it, because hardware back pops the route.
      //
      // So this taps what a player can see.
      await _pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();
      expect(find.byType(RoundScreen), findsOneWidget);

      await tester.tap(find.byType(IconButtonTile).first);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(RoundScreen), findsNothing);
    });

    testWidgets('a player can leave from a verdict screen too',
        (WidgetTester tester) async {
      // A verdict is its own full screen, so it needs its own exit — reaching
      // one by tapping "Siguiente" first would be an exit that depends on
      // answering another question.
      await _pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      for (final String id in <String>['4', '2', 'submit']) {
        await tester.tap(
          find.byWidgetPredicate(
            (Widget w) => w is KeypadKeyView && w.data.id == id,
          ),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(VerdictScreen), findsOneWidget);

      await tester.tap(find.byType(IconButtonTile).first);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('every full-screen session offers a visible way out',
        (WidgetTester tester) async {
      // The general rule rather than the two instances: whatever a session
      // shows, it shows a close control. A screen added later without one
      // fails here.
      await _pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      expect(find.byType(IconButtonTile), findsWidgets);

      for (final String id in <String>['4', '2', 'submit']) {
        await tester.tap(
          find.byWidgetPredicate(
            (Widget w) => w is KeypadKeyView && w.data.id == id,
          ),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(
        find.byType(IconButtonTile),
        findsWidgets,
        reason: 'the verdict screen has no way out',
      );
    });
  });

  group('every shipped puzzle can be started', () {
    testWidgets('each one opens from the home and comes back',
        _reachEveryPuzzle);
  });

  group('working on a puzzle records the day', () {
    /// Opens the named puzzle and returns the tester to it. The home scrolls,
    /// so the card has to be brought into view first.
    Future<void> openPuzzle(WidgetTester tester, String label) async {
      final Finder card = find.text(label);
      await tester.scrollUntilVisible(card, 120);
      await tester.tap(card);
      await tester.pumpAndSettle();
    }

    Future<void> leavePuzzle(WidgetTester tester) async {
      await tester.tap(find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.label == 'Salir',
      ));
      await tester.pumpAndSettle();
    }

    Future<void> typeOnTheBoard(WidgetTester tester) async {
      await tester.tap(find.byType(PuzzleBoardView));
      await tester.pump();
      await tester.tap(find.byWidgetPredicate(
        (Widget w) => w is KeypadKeyView && w.data.id == '1',
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the streak rises after a board without relaunching',
        (WidgetTester tester) async {
      // The gap this closes: five quick items earned a day and twenty minutes
      // on a KenKen earned nothing.
      final DayLogStore store = InMemoryDayLogStore(DayLog.empty);
      await _pump(tester, source: _puzzlePack, dayLog: store);
      await tester.pumpAndSettle();
      expect(find.text('0 DÍAS'), findsOneWidget);

      await openPuzzle(tester, 'KenKen');
      await typeOnTheBoard(tester);
      await leavePuzzle(tester);

      expect(find.text('1 DÍA'), findsOneWidget);
    });

    testWidgets('the streak rises after a word claimed',
        (WidgetTester tester) async {
      final DayLogStore store = InMemoryDayLogStore(DayLog.empty);
      await _pump(tester, source: _puzzlePack, dayLog: store);
      await tester.pumpAndSettle();

      await openPuzzle(tester, 'Sopa de letras');
      // SUMA runs along the top row. The grid hides a second word, so claiming
      // this one is practice without also finishing the puzzle — which would
      // pop the screen and make the assertion about solving instead.
      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.text('S')));
      for (final String letter in <String>['U', 'M', 'A']) {
        await gesture.moveTo(tester.getCenter(find.text(letter)));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      await leavePuzzle(tester);

      expect(find.text('1 DÍA'), findsOneWidget);
    });

    testWidgets('opening one and leaving records nothing',
        (WidgetTester tester) async {
      // Opening a screen is not practice, and a card that paid a streak day
      // for a tap would make the number meaningless.
      final DayLogStore store = InMemoryDayLogStore(DayLog.empty);
      await _pump(tester, source: _puzzlePack, dayLog: store);
      await tester.pumpAndSettle();

      await openPuzzle(tester, 'KenKen');
      await leavePuzzle(tester);

      expect(find.text('0 DÍAS'), findsOneWidget);
      expect((await store.read()).days, isEmpty);
    });

    testWidgets('a series and a puzzle on the same day count once',
        (WidgetTester tester) async {
      // `DayLog` holds days and never moments, so this is the store's property
      // — asserted through both surfaces, because that is where it would break.
      final DayLogStore store = InMemoryDayLogStore(DayLog.empty);
      await _pump(tester, source: _puzzlePack, dayLog: store);
      await tester.pumpAndSettle();

      await openPuzzle(tester, 'KenKen');
      await typeOnTheBoard(tester);
      await leavePuzzle(tester);

      expect(find.text('1 DÍA'), findsOneWidget);
      expect((await store.read()).days, hasLength(1));
    });
  });

  group('finishing a puzzle says so', () {
    /// Solves the test pack's 3×3 KenKen: 1 2 3 / 2 3 1 / 3 1 2.
    Future<void> solveTheBoard(WidgetTester tester) async {
      const List<List<int>> solution = <List<int>>[
        <int>[1, 2, 3],
        <int>[2, 3, 1],
        <int>[3, 1, 2],
      ];
      for (int row = 0; row < 3; row += 1) {
        for (int col = 0; col < 3; col += 1) {
          // Scoped to the board: the header buttons and every keypad key are
          // gesture detectors too, so an unscoped index taps something else
          // and the test passes having exercised nothing.
          await tester.tap(
            find
                .descendant(
                  of: find.byType(PuzzleBoardView),
                  matching: find.byType(GestureDetector),
                )
                .at(row * 3 + col),
          );
          await tester.pump();
          await tester.tap(find.byWidgetPredicate(
            (Widget w) =>
                w is KeypadKeyView && w.data.id == '${solution[row][col]}',
          ));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();
    }

    Future<void> openPuzzle(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(find.text(label), 120);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('a solved board is acknowledged, and the way out goes home',
        (WidgetTester tester) async {
      // Before this, twenty minutes of Kakuro ended with the screen simply
      // going away — which reads as the app losing your place.
      await _pump(tester, source: _puzzlePack);
      await tester.pumpAndSettle();

      await openPuzzle(tester, 'KenKen');
      await solveTheBoard(tester);

      expect(find.byType(PuzzleSolvedScreen), findsOneWidget);
      expect(find.text('KenKen'), findsOneWidget, reason: 'it names the format');
      expect(find.byType(PuzzleScreen), findsNothing,
          reason: 'the finished board is still underneath');

      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
      expect(find.text('ROMPECABEZAS'), findsOneWidget);
    });

    testWidgets('a solved sopa de letras is acknowledged too',
        (WidgetTester tester) async {
      await _pump(tester, source: _puzzlePack);
      await tester.pumpAndSettle();

      await openPuzzle(tester, 'Sopa de letras');
      for (final List<String> word in <List<String>>[
        <String>['S', 'U', 'M', 'A'],
        <String>['C', 'E', 'R', 'O'],
      ]) {
        final TestGesture gesture =
            await tester.startGesture(tester.getCenter(find.text(word.first)));
        for (final String letter in word.skip(1)) {
          await gesture.moveTo(tester.getCenter(find.text(letter)));
        }
        await gesture.up();
        await tester.pumpAndSettle();
      }

      expect(find.byType(PuzzleSolvedScreen), findsOneWidget);
      expect(find.text('Sopa de letras'), findsOneWidget);
    });

    testWidgets('leaving one unsolved shows nothing',
        (WidgetTester tester) async {
      await _pump(tester, source: _puzzlePack);
      await tester.pumpAndSettle();

      await openPuzzle(tester, 'KenKen');
      await tester.tap(find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.label == 'Salir',
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PuzzleSolvedScreen), findsNothing);
      expect(find.text('ROMPECABEZAS'), findsOneWidget);
    });

    testWidgets('the streak it shows is the one the home will show',
        (WidgetTester tester) async {
      // The day was recorded the moment the player first put a value on the
      // board, but `_log` is only re-read on the way back — so reading it
      // straight would print a streak one short of the one the home prints a
      // second later. That is the two-screens-one-morning contradiction
      // `StreakPolicy` was fixed for, in the other direction.
      final DayLogStore store = InMemoryDayLogStore(DayLog.empty);
      await _pump(tester, source: _puzzlePack, dayLog: store);
      await tester.pumpAndSettle();

      await openPuzzle(tester, 'KenKen');
      await solveTheBoard(tester);

      final PuzzleSolvedScreen screen =
          tester.widget<PuzzleSolvedScreen>(find.byType(PuzzleSolvedScreen));
      expect(screen.streakDays, 1);

      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
      expect(find.text('1 DÍA'), findsOneWidget,
          reason: 'the home disagreed with the screen before it');
    });

    testWidgets('the time is the route\'s, from opening the puzzle',
        (WidgetTester tester) async {
      // The clock is injected, so the elapsed figure is a fact about the
      // session and not about how fast the test ran.
      DateTime now = DateTime(2026, 8, 16, 9);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeRoute(
            reader: PackReader(bundle: _FakeBundle(_puzzlePack)),
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openPuzzle(tester, 'KenKen');
      now = now.add(const Duration(minutes: 3, seconds: 20));
      await solveTheBoard(tester);

      final PuzzleSolvedScreen screen =
          tester.widget<PuzzleSolvedScreen>(find.byType(PuzzleSolvedScreen));
      expect(screen.elapsed, const Duration(minutes: 3, seconds: 20));
    });
  });

  group('a wrong answer in a real round is told why', () {
    testWidgets('the fallback steps reach the screen',
        (WidgetTester tester) async {
      // End to end, because every piece of this can be right on its own and
      // still not be wired: the pack carries the copy, the route hands it to
      // the round, the round asks `diagnose`, and the verdict screen draws it.
      await _pump(tester, source: _puzzlePack);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      for (final String id in <String>['1', 'submit']) {
        await tester.tap(find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == id,
        ));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('Lee otra vez el reto'), findsOneWidget);
    });

    testWidgets('a right answer is told nothing', (WidgetTester tester) async {
      await _pump(tester, source: _puzzlePack);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      for (final String id in <String>['4', '2', 'submit']) {
        await tester.tap(find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == id,
        ));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('Lee otra vez el reto'), findsNothing);
    });
  });

  group('playing records the day', () {
    testWidgets('the streak rises after a series without relaunching',
        (WidgetTester tester) async {
      // The whole point of the store: the home re-reads it when the series
      // ends rather than holding a number it computed once.
      final DayLogStore store = InMemoryDayLogStore(
        DayLog.empty.recording(DateTime(2026, 8, 15)),
      );

      await _pump(tester, dayLog: store);
      await tester.pumpAndSettle();
      expect(find.text('1 DÍA'), findsOneWidget, reason: 'yesterday alone');

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      // Answer the item.
      for (final String id in <String>['4', '2', 'submit']) {
        await tester.tap(
          find.byWidgetPredicate(
            (Widget w) => w is KeypadKeyView && w.data.id == id,
          ),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(RoundScreen))).pop();
      await tester.pumpAndSettle();

      expect(
        find.text('2 DÍAS'),
        findsOneWidget,
        reason: 'today was not recorded, or the home did not re-read',
      );
    });

    testWidgets('coming back to the front re-reads the streak, and a rebuild '
        'behind does not', (WidgetTester tester) async {
      // PROC-13, and the mirror of the map's own case. `_refreshLog` runs when
      // a series this route pushed comes back, so a day recorded by practising
      // from Mapa left the home saying `1 DÍA` — the map hands the practice
      // round the same `DayLogStore` the home reads, and `IndexedStack` keeps
      // the home alive with no second `initState` to hook.
      final DayLogStore store = InMemoryDayLogStore(
        DayLog.empty.recording(DateTime(2026, 8, 15)),
      );

      await _pump(tester, dayLog: store, visibility: RootVisibility.behind);
      await tester.pumpAndSettle();
      expect(find.text('1 DÍA'), findsOneWidget, reason: 'yesterday alone');

      // A practice run on Mapa records today, while the home sits behind it.
      await store.record(DateTime(2026, 8, 16));

      // **A rebuild is not a visit.** The shell rebuilds every root on every
      // tab switch, so reading here would read storage for a screen nobody is
      // looking at, and would hide the case this exists for.
      await _pumpAgain(
        tester,
        dayLog: store,
        visibility: RootVisibility.behind,
      );
      await tester.pumpAndSettle();
      expect(find.text('1 DÍA'), findsOneWidget);

      // Now the player taps `Inicio`.
      await _pumpAgain(
        tester,
        dayLog: store,
        visibility: RootVisibility.showing,
      );
      await tester.pumpAndSettle();
      expect(find.text('2 DÍAS'), findsOneWidget);
    });

    testWidgets('a wrong answer records the day just the same',
        (WidgetTester tester) async {
      // The streak counts days practised, not days won.
      final DayLogStore store = InMemoryDayLogStore();

      await _pump(tester, dayLog: store);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      for (final String id in <String>['9', 'submit']) {
        await tester.tap(
          find.byWidgetPredicate(
            (Widget w) => w is KeypadKeyView && w.data.id == id,
          ),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect((await store.read()).days, hasLength(1));
    });
  });

  group('the summary draws the series that was actually played', () {
    // **`2.5` was built with a ring and a diagnosis card and got neither.**
    // `SeriesResult` defaults `outcomes` to empty and `stumble` to null, so a
    // route that omits them compiles, renders, and quietly falls back to
    // `"2 de 2"` in words — a screen that is right about the score and silent
    // about which item was missed. Nothing but an end-to-end play can see it.

    /// Answers [keys] on whichever pad is up, then submits.
    Future<void> answer(WidgetTester tester, List<String> keys) async {
      for (final String id in <String>[...keys, 'submit']) {
        await tester.tap(find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == id,
        ));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    /// Leaves the verdict screen by whichever label it is showing.
    Future<void> carryOn(WidgetTester tester) async {
      await tester.tap(find.text('Siguiente').evaluate().isEmpty
          ? find.text('Intentar otro')
          : find.text('Siguiente'));
      await tester.pumpAndSettle();
    }

    testWidgets('one mark per answered item, not the score in words',
        (WidgetTester tester) async {
      await _pump(tester, source: _twoItemPack);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      await answer(tester, <String>['4', '2']);
      await carryOn(tester);
      await answer(tester, <String>['1', '7']);
      await carryOn(tester);

      expect(find.byType(SeriesSummaryScreen), findsOneWidget);
      expect(
        find.byType(VerdictRing),
        findsNWidgets(2),
        reason: 'the round knew both outcomes and the summary drew none',
      );
      expect(
        find.text('2 de 2'),
        findsNothing,
        reason: 'the score in words is the fallback for a caller with no '
            'outcomes, and this caller has them',
      );
    });

    testWidgets('the coral card names the reto that went wrong',
        (WidgetTester tester) async {
      await _pump(tester, source: _twoItemPack);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      // Wrong on the first, right on the second: the card explains the
      // earliest slip and numbers it from one.
      await answer(tester, <String>['9']);
      await carryOn(tester);
      await answer(tester, <String>['1', '7']);
      await carryOn(tester);

      expect(find.text('QUÉ SE TORCIÓ'), findsOneWidget);
      expect(find.text('Reto 1'), findsOneWidget);
      expect(find.textContaining('Lee otra vez el reto'), findsOneWidget);
    });

    testWidgets('a clean series draws no diagnosis card at all',
        (WidgetTester tester) async {
      // The card is absent rather than empty — the same reading `HISTORIAL`
      // takes on `4.1`.
      await _pump(tester, source: _twoItemPack);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      await answer(tester, <String>['4', '2']);
      await carryOn(tester);
      await answer(tester, <String>['1', '7']);
      await carryOn(tester);

      expect(find.text('QUÉ SE TORCIÓ'), findsNothing);
    });
  });
}
