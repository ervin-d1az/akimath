import 'dart:convert';

import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/policy/day_log.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/round/ui/verdict/verdict_screen.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  String source = _pack,
  Duration delay = Duration.zero,
  DayLogStore? dayLog,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: HomeRoute(
        reader: PackReader(bundle: _FakeBundle(source, delay: delay)),
        now: () => DateTime(2026, 8, 16),
        dayLog: dayLog,
      ),
    ),
  );
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

      expect(find.text('2'), findsOneWidget);
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
      expect(find.text('1'), findsOneWidget, reason: 'yesterday alone');

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
        find.text('2'),
        findsOneWidget,
        reason: 'today was not recorded, or the home did not re-read',
      );
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
}
