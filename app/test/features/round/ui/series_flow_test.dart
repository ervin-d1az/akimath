import 'dart:convert';

import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/round/policy/series_plan.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/round/ui/summary/series_summary_screen.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.source);
  final String source;
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(source));
}

/// A pack of eight, so a five-item series is genuinely a subset.
String _pack(int count) {
  final List<String> items = List<String>.generate(
    count,
    (int i) => '''
    {
      "id": "a$i",
      "ladder_step": 1,
      "answer": "${i + 1}",
      "prompt": [
        {"kind": "text", "value": "${i + 1}"},
        {"kind": "operator", "glyph": "+"},
        {"kind": "text", "value": "0"},
        {"kind": "operator", "glyph": "="}
      ]
    }''',
  );
  return '''
{
  "pack_version": 1,
  "pack_id": "flow",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "2099-01-01T00:00:00Z",
  "items": [${items.join(',')}]
}
''';
}

Future<void> _pump(WidgetTester tester, {int packSize = 8}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: HomeRoute(
        reader: PackReader(bundle: _FakeBundle(_pack(packSize))),
        dayLog: InMemoryDayLogStore(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, String id) async {
  await tester.tap(
    find.byWidgetPredicate((Widget w) => w is KeypadKeyView && w.data.id == id),
  );
  await tester.pump();
}

/// Answers whatever item is on screen correctly and acknowledges the verdict.
Future<void> _answer(WidgetTester tester, int answer) async {
  await _press(tester, '$answer');
  await _press(tester, 'submit');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Siguiente'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('a series is five items and then it ends', () {
    testWidgets('the fifth answer brings the summary, not a sixth item',
        (WidgetTester tester) async {
      await _pump(tester);
      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      for (int i = 1; i <= seriesLength; i++) {
        expect(find.text('Reto $i'), findsOneWidget, reason: 'at item $i');
        await _answer(tester, i);
      }

      expect(find.byType(SeriesSummaryScreen), findsOneWidget);
      expect(find.byType(RoundScreen), findsNothing);
      expect(find.byType(Keypad), findsNothing);
    });

    testWidgets('it does not wrap back to the first item',
        (WidgetTester tester) async {
      // The behaviour before this change: `_next` took the index modulo the
      // item list and played forever. A test that only counts to five would
      // pass for a round that then offered a sixth.
      await _pump(tester);
      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      for (int i = 1; i <= seriesLength; i++) {
        await _answer(tester, i);
      }

      expect(find.text('Reto 1'), findsNothing);
      expect(find.text('Reto 6'), findsNothing);
    });

    testWidgets('the summary reports the series, and the way back works',
        (WidgetTester tester) async {
      await _pump(tester);
      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      for (int i = 1; i <= seriesLength; i++) {
        await _answer(tester, i);
      }

      expect(find.text('5 de 5'), findsOneWidget);

      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SeriesSummaryScreen), findsNothing);
    });

    testWidgets('a wrong answer is counted as such', (WidgetTester tester) async {
      // The control: `5 de 5` above is also what a screen showing the total
      // twice would print.
      await _pump(tester);
      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      await _press(tester, '9'); // item 1 wants 1
      await _press(tester, 'submit');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Intentar otro'));
      await tester.pumpAndSettle();

      for (int i = 2; i <= seriesLength; i++) {
        await _answer(tester, i);
      }

      expect(find.text('4 de 5'), findsOneWidget);
    });
  });

  group('the streak survives the series', () {
    testWidgets('playing records today, and the home shows it afterwards',
        (WidgetTester tester) async {
      await _pump(tester);
      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();
      for (int i = 1; i <= seriesLength; i++) {
        await _answer(tester, i);
      }
      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();

      // The home re-reads the store rather than holding a number it computed
      // once, which is what makes the streak visible without a relaunch.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('1'), findsWidgets);
    });
  });
}
