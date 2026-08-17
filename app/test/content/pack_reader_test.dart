import 'dart:convert';

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
