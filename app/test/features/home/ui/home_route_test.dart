import 'dart:convert';

import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/shell/ui/skeleton_block.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/design/widgets/loading_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  List<DateTime> attemptDays = const <DateTime>[],
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
        attemptDays: attemptDays,
      ),
    ),
  );
}

void main() {
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
        attemptDays: <DateTime>[DateTime(2026, 8, 15), DateTime(2026, 8, 16)],
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

    testWidgets('the session can be left and the home is still there',
        (WidgetTester tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(RoundScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(RoundScreen), findsNothing);
    });
  });
}
