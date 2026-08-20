import 'dart:convert';

import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/policy/day_log.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/states/data/streak_notice_store.dart';
import 'package:akimath_app/features/states/ui/streak_at_risk_screen.dart';
import 'package:akimath_app/features/states/ui/streak_lost_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Whether either streak screen can be *reached*, which is a different
/// question from whether it renders.
///
/// **The gate the `pack.puzzles.first` defect walked past.** Four of five
/// shipped board formats were unreachable with every suite green, because
/// nothing asked this. A `CenteredStateView` composition with no caller is
/// decoration, so both screens are walked to from a seeded log and both ways
/// out are taken.

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(source));
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

/// A run of [length] days ending on [last].
DayLog runEnding(DateTime last, int length) {
  DayLog log = DayLog.empty;
  for (int back = length - 1; back >= 0; back--) {
    log = log.recording(DateTime(last.year, last.month, last.day - back));
  }
  return log;
}

Future<void> pumpHome(
  WidgetTester tester, {
  required DateTime now,
  required DayLog log,
  StreakNoticeStore? notices,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: HomeRoute(
        reader: PackReader(bundle: _FakeBundle(_pack)),
        now: () => now,
        dayLog: InMemoryDayLogStore(log),
        streakNotices: notices ?? InMemoryStreakNoticeStore(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('4.12 is reachable and both its ways out lead somewhere', () {
    testWidgets('a late launch with a live run and nothing today shows it',
        (WidgetTester tester) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 8, 20, 20, 14),
        log: runEnding(DateTime(2026, 8, 19), 13),
      );

      expect(find.byType(StreakAtRiskScreen), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.textContaining('TE QUEDAN'), findsOneWidget);
    });

    testWidgets('the same log early in the day goes straight to the home',
        (WidgetTester tester) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 8, 20, 7, 12),
        log: runEnding(DateTime(2026, 8, 19), 13),
      );

      expect(find.byType(StreakAtRiskScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('its primary action opens a round', (WidgetTester tester) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 8, 20, 20, 14),
        log: runEnding(DateTime(2026, 8, 19), 13),
      );

      await tester.tap(find.text('Resolver uno ahora'));
      await tester.pumpAndSettle();

      expect(find.byType(RoundScreen), findsOneWidget);
    });

    testWidgets('its secondary action lands on the home', (WidgetTester tester) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 8, 20, 20, 14),
        log: runEnding(DateTime(2026, 8, 19), 13),
      );

      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(find.byType(StreakAtRiskScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a day already recorded shows nothing at all', (WidgetTester tester) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 8, 20, 20, 14),
        log: runEnding(DateTime(2026, 8, 20), 13),
      );

      expect(find.byType(StreakAtRiskScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('4.13 is reachable and turns the page once', () {
    testWidgets('a launch after a broken run shows it', (WidgetTester tester) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 8, 20, 8, 2),
        log: runEnding(DateTime(2026, 8, 17), 13),
      );

      expect(find.byType(StreakLostScreen), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('its action opens a round', (WidgetTester tester) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 8, 20, 8, 2),
        log: runEnding(DateTime(2026, 8, 17), 13),
      );

      await tester.tap(find.text('Empezar la de hoy'));
      await tester.pumpAndSettle();

      expect(find.byType(RoundScreen), findsOneWidget);
    });

    testWidgets('a page already turned today is not turned again',
        (WidgetTester tester) async {
      final InMemoryStreakNoticeStore notices =
          InMemoryStreakNoticeStore(DateTime(2026, 8, 20));

      await pumpHome(
        tester,
        now: DateTime(2026, 8, 20, 8, 2),
        log: runEnding(DateTime(2026, 8, 17), 13),
        notices: notices,
      );

      expect(find.byType(StreakLostScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('showing it records the day, so a relaunch goes home',
        (WidgetTester tester) async {
      // The record is what makes *"se pasa la página"* true across launches,
      // and writing it is the half a screen test cannot see.
      final InMemoryStreakNoticeStore notices = InMemoryStreakNoticeStore();

      await pumpHome(
        tester,
        now: DateTime(2026, 8, 20, 8, 2),
        log: runEnding(DateTime(2026, 8, 17), 13),
        notices: notices,
      );
      expect(find.byType(StreakLostScreen), findsOneWidget);

      expect(await notices.lostShownOn(), DateTime(2026, 8, 20));
    });

    testWidgets('the warning is not recorded, so it comes back',
        (WidgetTester tester) async {
      // Deliberately asymmetric: the day is still at risk on the second launch
      // and nothing about it has changed.
      final InMemoryStreakNoticeStore notices = InMemoryStreakNoticeStore();

      await pumpHome(
        tester,
        now: DateTime(2026, 8, 20, 20, 14),
        log: runEnding(DateTime(2026, 8, 19), 13),
        notices: notices,
      );
      expect(find.byType(StreakAtRiskScreen), findsOneWidget);

      expect(await notices.lostShownOn(), isNull);
    });
  });

  group('a player with no history sees neither', () {
    testWidgets('an empty log opens the home', (WidgetTester tester) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 8, 20, 20, 14),
        log: DayLog.empty,
      );

      expect(find.byType(StreakAtRiskScreen), findsNothing);
      expect(find.byType(StreakLostScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
