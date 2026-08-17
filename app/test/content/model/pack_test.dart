import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/model/pack.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _packJson({
  String expiresAt = '2027-01-01T00:00:00Z',
  List<Map<String, dynamic>>? items,
}) {
  return <String, dynamic>{
    'pack_version': 1,
    'pack_id': 'starter',
    'issued_at': '2026-08-01T00:00:00Z',
    'expires_at': expiresAt,
    'items': items ??
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'a1',
            'ladder_step': 3,
            'answer': '5/4',
            'prompt': <Map<String, dynamic>>[
              <String, dynamic>{
                'kind': 'fraction',
                'numerator': '3',
                'denominator': '4',
              },
              <String, dynamic>{'kind': 'operator', 'glyph': '+'},
              <String, dynamic>{'kind': 'text', 'value': '1'},
              <String, dynamic>{'kind': 'operator', 'glyph': '='},
            ],
          },
        ],
  };
}

void main() {
  group('a pack is read from its declared shape', () {
    test('it yields the declared item count and each item s payload', () {
      final Pack pack = Pack.fromJson(_packJson());

      expect(pack.id, 'starter');
      expect(pack.items, hasLength(1));

      final Item item = pack.items.single;
      expect(item.id, 'a1');
      expect(item.expected, '5/4');
      expect(item.prompt, hasLength(4));
      expect(item.prompt.first, isA<FractionToken>());
      expect(item.prompt[1], isA<OperatorToken>());
      expect(item.prompt[2], isA<TextToken>());
    });

    test('difficulty comes from the pack and is never computed here', () {
      final Pack pack = Pack.fromJson(_packJson());
      expect(pack.items.single.ladderStep, 3);
    });
  });

  group('an expired pack is refused', () {
    test('a pack past its expiry is expired against an injected now', () {
      final Pack pack =
          Pack.fromJson(_packJson(expiresAt: '2026-08-10T00:00:00Z'));

      expect(
        pack.isExpiredAt(DateTime.utc(2026, 8, 16)),
        isTrue,
      );
      expect(
        pack.isExpiredAt(DateTime.utc(2026, 8, 1)),
        isFalse,
      );
    });

    test('expiry reads an injected clock, never the ambient one', () {
      // Two calls with two different `now` values must disagree. A module
      // reaching for DateTime.now() would return the same answer for both.
      final Pack pack =
          Pack.fromJson(_packJson(expiresAt: '2026-08-10T00:00:00Z'));

      expect(
        pack.isExpiredAt(DateTime.utc(2026, 1, 1)),
        isNot(pack.isExpiredAt(DateTime.utc(2027, 1, 1))),
      );
    });
  });

  group('a malformed pack is rejected rather than half-read', () {
    test('a missing items list throws', () {
      final Map<String, dynamic> broken = _packJson()..remove('items');
      expect(() => Pack.fromJson(broken), throwsA(isA<FormatException>()));
    });

    test('an unknown prompt token kind throws', () {
      expect(
        () => Pack.fromJson(
          _packJson(
            items: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'bad',
                'ladder_step': 1,
                'answer': '1',
                'prompt': <Map<String, dynamic>>[
                  <String, dynamic>{'kind': 'hologram'},
                ],
              },
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('an item whose answer is not storage-canonical throws', () {
      // The pack is content, and broken content should fail where it is read
      // rather than show a player a wrong verdict for a right answer.
      expect(
        () => Pack.fromJson(
          _packJson(
            items: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'bad',
                'ladder_step': 1,
                'answer': ' 007 ',
                'prompt': <Map<String, dynamic>>[
                  <String, dynamic>{'kind': 'text', 'value': '7'},
                ],
              },
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('an empty pack throws', () {
      expect(
        () => Pack.fromJson(_packJson(items: <Map<String, dynamic>>[])),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
