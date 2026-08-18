import 'dart:convert';
import 'dart:io';

import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/model/pack.dart';
import 'package:akimath_app/content/pack_reader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// An `AssetBundle` that serves what the test hands it.
///
/// The reader is an adapter, so the thing worth testing is that it reads the
/// bundle it was given and nothing else — no network, no filesystem, no ambient
/// `rootBundle`.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.contents);

  final Map<String, String> contents;
  final List<String> requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    final String? value = contents[key];
    if (value == null) {
      throw StateError('no asset at $key');
    }
    return ByteData.sublistView(utf8.encode(value));
  }
}

/// A bundle that fails if anyone reaches for `loadString`.
///
/// `CachingAssetBundle.loadString` is the method with the 50 KB isolate cliff,
/// so the gate is that the reader does not call it — asserted here rather than
/// inferred from a test that happens to be fast.
class _StringRefusingBundle extends CachingAssetBundle {
  _StringRefusingBundle(this.source);

  final String source;
  bool askedForAString = false;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(source));

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    askedForAString = true;
    throw StateError('the reader must decode the bytes itself');
  }
}

const String _minimalPack = '''
{
  "pack_version": 1,
  "pack_id": "test",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "2027-01-01T00:00:00Z",
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

void main() {
  group('a pack is read from the bundle', () {
    test('it yields the declared items', () async {
      final _FakeBundle bundle =
          _FakeBundle(<String, String>{'p.json': _minimalPack});

      final Pack pack = await PackReader(bundle: bundle).load('p.json');

      expect(pack.id, 'test');
      expect(pack.items, hasLength(1));
      expect(pack.items.single.expected, '42');
      expect(pack.items.single.ladderStep, 2);
    });

    test('it asks the bundle for exactly the path it was given', () async {
      final _FakeBundle bundle =
          _FakeBundle(<String, String>{'p.json': _minimalPack});

      await PackReader(bundle: bundle).load('p.json');

      expect(bundle.requested, <String>['p.json']);
    });

    test('malformed JSON surfaces as a FormatException', () async {
      final _FakeBundle bundle =
          _FakeBundle(<String, String>{'p.json': '[1, 2, 3]'});

      expect(
        () => PackReader(bundle: bundle).load('p.json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('a broken pack fails at load, not at play', () async {
      final _FakeBundle bundle = _FakeBundle(<String, String>{
        'p.json': _minimalPack.replaceAll('"42"', '" 007 "'),
      });

      expect(
        () => PackReader(bundle: bundle).load('p.json'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('it decodes the bytes itself', () {
    testWidgets('it never asks the bundle for a string',
        (WidgetTester tester) async {
      // Flutter hands a UTF-8 decode over 50 KB to a background isolate, and
      // an isolate never completes inside `testWidgets`' fake-async zone. The
      // shipped pack crossed 50 KB the day it started carrying several boards
      // per format, and every widget test that loads it stopped failing and
      // started *hanging* for ten minutes.
      final _StringRefusingBundle bundle = _StringRefusingBundle(_minimalPack);

      final Pack pack = await PackReader(bundle: bundle).load();

      expect(pack.id, 'test');
      expect(bundle.askedForAString, isFalse);
    });

    testWidgets('the shipped pack loads inside a widget test',
        (WidgetTester tester) async {
      // The regression itself, at the size that triggers it. This is a fast
      // test only because the decode stays on this isolate; before the fix it
      // was a ten-minute timeout.
      final Pack pack = await const PackReader().load();
      expect(pack.puzzles, isNotEmpty);

      // If the pack ever drops back under the threshold this stops covering
      // the regression, and a green tick would be saying something it no longer
      // checks. `_StringRefusingBundle` above is the gate that does not depend
      // on the file's size; this one is the end-to-end case, and it declares
      // what makes it one.
      final int bytes = File(PackReader.starterPath).lengthSync();
      expect(bytes, greaterThan(50 * 1024),
          reason: 'the shipped pack is below the isolate threshold again '
              '($bytes bytes), so this test no longer exercises it');
    });
  });

  group('the pack that ships is valid', () {
    testWidgets('the starter pack loads and every item is well formed',
        (WidgetTester tester) async {
      // Reads the real asset through the real bundle. This is the test that
      // would have caught a typo in the committed pack, which is otherwise a
      // file nothing checks.
      final Pack pack = await PackReader().load();

      expect(pack.items.length, greaterThanOrEqualTo(20));
      expect(pack.id, 'starter');
      expect(
        pack.isExpiredAt(DateTime.utc(2026, 8, 16)),
        isFalse,
        reason: 'the shipped pack is already expired',
      );

      final Set<String> ids = <String>{};
      for (final Item item in pack.items) {
        expect(ids.add(item.id), isTrue, reason: 'duplicate id');
      }
      // ignore: avoid_print
      print('  starter pack · items → ${pack.items.length}');
    });
  });
}
