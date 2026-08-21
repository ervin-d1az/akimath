import 'dart:convert';

import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/onboarding/ui/first_item_screen.dart';
import 'package:akimath_app/features/stats/data/answer_record_store.dart';
import 'package:akimath_app/features/stats/policy/local_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Whether playing actually *leaves* something behind.
///
/// **The store shipped with no writer.** `LocalStats` and `AnswerRecordStore`
/// both landed and nothing called `record`, so `4.1`'s accuracy and mean time
/// could only ever come from `DemoFigures` however much anybody played — the
/// `pack.puzzles.first` shape, where the piece renders and no caller reaches
/// it. These tests ask the only question that catches that: after a real
/// series, is there a row?

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(source));
}

/// Two items, so a series ends rather than offering the same one again — and
/// so one right answer and one wrong can be told apart in the record.
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

/// One item, which is the only shape that can be *retried*: `RoundScreen`
/// offers `Intentar otro` on a slip, and with nothing else to offer it comes
/// back to the same item.
const String _oneItemPack = '''
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

/// A clock that moves, so a recorded duration is a measurement rather than the
/// zero every fixed-`now` test would report either way (PROC-11).
class _TickingClock {
  DateTime _at = DateTime(2026, 8, 16, 9);

  DateTime call() {
    _at = _at.add(const Duration(seconds: 1));
    return _at;
  }
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required AnswerRecordStore record,
  String source = _twoItemPack,
  DateTime Function()? now,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: HomeRoute(
        reader: PackReader(bundle: _FakeBundle(source)),
        now: now ?? () => DateTime(2026, 8, 16),
        answerRecord: record,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types [keys] on whichever keypad is on screen and submits.
Future<void> _answer(WidgetTester tester, List<String> keys) async {
  for (final String id in <String>[...keys, 'submit']) {
    await tester.tap(
      find.byWidgetPredicate(
        (Widget w) => w is KeypadKeyView && w.data.id == id,
      ),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Moves past the verdict screen to whatever comes next.
///
/// The label is the verdict's own: `Siguiente` on a win, `Intentar otro` on a
/// slip, because the button asks for another go rather than acknowledging one.
Future<void> _carryOn(WidgetTester tester) async {
  final Finder onward = find.text('Siguiente').evaluate().isEmpty
      ? find.text('Intentar otro')
      : find.text('Siguiente');
  await tester.tap(onward);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('a played series leaves a record on the device', () {
    testWidgets('every answer is remembered, right and wrong alike',
        (WidgetTester tester) async {
      final InMemoryAnswerRecordStore record = InMemoryAnswerRecordStore();

      await _pumpHome(tester, record: record);
      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      await _answer(tester, <String>['9']);
      await _carryOn(tester);
      await _answer(tester, <String>['1', '7']);
      await tester.pumpAndSettle();

      expect(
        (await record.read()).map((AnsweredItem a) => a.verdict).toList(),
        <Verdict>[Verdict.wrong, Verdict.correct],
        reason: 'the round graded two answers and the device kept neither',
      );
    });

    testWidgets('the time on the item is measured, not defaulted',
        (WidgetTester tester) async {
      // `elapsed` is the only field a mis-wiring can quietly zero: a recorder
      // hung off the wrong callback still gets a verdict.
      final InMemoryAnswerRecordStore record = InMemoryAnswerRecordStore();

      await _pumpHome(tester, record: record, now: _TickingClock().call);
      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      await _answer(tester, <String>['4', '2']);

      final List<AnsweredItem> kept = await record.read();
      expect(kept, hasLength(1));
      expect(kept.single.elapsed, greaterThan(Duration.zero));
    });

    testWidgets('a retried item is a second answer, not a correction',
        (WidgetTester tester) async {
      // **Deliberate, and it is `AnsweredItem`'s own reading**: *"a replayed
      // item is a second answer, and counting it twice is what actually
      // happened."* It is also why the record and `2.5`'s ring can differ —
      // the ring shows one mark per *item*, this counts *answers* — so the
      // divergence is pinned here rather than discovered later.
      final InMemoryAnswerRecordStore record = InMemoryAnswerRecordStore();

      await _pumpHome(tester, record: record, source: _oneItemPack);
      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      await _answer(tester, <String>['9']);
      await _carryOn(tester);
      await _answer(tester, <String>['4', '2']);
      await tester.pumpAndSettle();

      expect(
        (await record.read()).map((AnsweredItem a) => a.verdict).toList(),
        <Verdict>[Verdict.wrong, Verdict.correct],
      );
    });
  });

  group('the teaching item stays out of the figures', () {
    testWidgets('solving 0.3 Primer reto writes nothing to the record',
        (WidgetTester tester) async {
      // **The device's own store, not an injected one.** The rule is that
      // nothing reaches a recorder from here at all, so the thing to assert is
      // that the real key stays empty — an injected store would only prove
      // that the object this test made was left alone.
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: FirstItemScreen(onFinished: () {}, onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();

      await _answer(tester, <String>['1', '3']);

      expect(
        await const PrefsAnswerRecordStore().read(),
        isEmpty,
        reason: 'the tutorial moved a figure it is not allowed to move',
      );
    });
  });
}
