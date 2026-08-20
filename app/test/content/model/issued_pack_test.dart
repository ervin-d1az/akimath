import 'dart:convert';
import 'dart:io';

import 'package:akimath_app/content/answer_digest.dart';
import 'package:akimath_app/content/model/issued_pack.dart';
import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/model/pack.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reader for the pack the server issues, against the real artifact.
///
/// **Not a hand-written fixture.** `packages/core/pack/starter.json` is what
/// `POST /packs` returns a copy of, byte for byte, so reading it here is
/// reading production content. A fixture would be a second thing that can be
/// right while the real one is wrong.
Map<String, dynamic> shippedContent() => jsonDecode(
      File('../packages/core/pack/starter.json').readAsStringSync(),
    ) as Map<String, dynamic>;

Pack readShipped({String packId = 'pk_1'}) => readIssuedPack(
      shippedContent(),
      packId: packId,
      issuedAt: DateTime.utc(2026, 8, 20),
      expiresAt: DateTime.utc(2026, 9, 20),
    );

void main() {
  group('the frozen envelope', () {
    test('reads every item the artifact carries, and the count is reported', () {
      final Pack pack = readShipped();

      expect(pack.items, isNotEmpty, reason: 'items read → ${pack.items.length}');
      expect(pack.items, hasLength(shippedContent()['items']!.length));
    });

    test('reads its puzzles too', () {
      final Pack pack = readShipped();

      expect(pack.puzzles, isNotEmpty,
          reason: 'puzzles read → ${pack.puzzles.length}');
    });

    test('takes the instants from the row, not from the content', () {
      // The content is one artifact shared by every player; when it was issued
      // and when it lapses belong to the row the server wrote.
      final Pack pack = readShipped();

      expect(pack.issuedAt, DateTime.utc(2026, 8, 20));
      expect(pack.expiresAt, DateTime.utc(2026, 9, 20));
    });

    test('carries the fallback line, so a wrong answer is never wordless', () {
      expect(readShipped().fallbackDiagnosis, isNotNull);
    });
  });

  group('an item states a digest and never an answer', () {
    test('every one of them', () {
      for (final Item item in readShipped().items) {
        expect(item.answer, isA<DigestAnswer>(), reason: item.id);
      }
    });

    test('and reading a plaintext answer off one throws', () {
      expect(() => readShipped().items.first.expected, throwsStateError);
    });

    test('every digest is keyed on the pack salt', () {
      final String salt = shippedContent()['pack_salt']! as String;

      for (final Item item in readShipped().items.take(5)) {
        expect((item.answer as DigestAnswer).saltHex, salt);
      }
    });
  });

  group("an item's id is its address", () {
    test('it is the packId and the index, in order', () {
      final Pack pack = readShipped(packId: 'pk_abc');

      expect(pack.items[0].id, 'pk_abc#0');
      expect(pack.items[7].id, 'pk_abc#7');
    });

    test('and it reads back into the pair an attempt names', () {
      final Pack pack = readShipped(packId: 'pk_abc');
      final ({String packId, int index})? parsed =
          readIssuedItemId(pack.items[7].id);

      expect(parsed?.packId, 'pk_abc');
      expect(parsed?.index, 7);
    });

    test('a pack id containing a hash still splits at the right one', () {
      // `lastIndexOf`, not `indexOf`. Nothing mints such an id today and the
      // cost of being wrong is an attempt filed against another pack.
      expect(readIssuedItemId('pk#weird#3')?.packId, 'pk#weird');
      expect(readIssuedItemId('pk#weird#3')?.index, 3);
    });

    test('anything that is not an address reads as none', () {
      for (final String bad in <String>['', 'sin-hash', '#3', 'pk#', 'pk#x', 'pk#-1']) {
        expect(readIssuedItemId(bad), isNull, reason: bad);
      }
    });
  });

  group('the loop this exists for', () {
    test('the device can grade an issued item with no answer in the file', () {
      // The whole point, end to end on the client side: the content carries an
      // HMAC, the player types, and the device says right or wrong. The answer
      // to `7 + 6` is not in the bytes the server sent.
      final Pack pack = readShipped();
      final Item first = pack.items.first;
      final String salt = shippedContent()['pack_salt']! as String;

      // Sanity: the artifact's first item is the one the digest was taken over.
      expect(
        (first.answer as DigestAnswer).digest,
        answerDigest(saltHex: salt, canonicalAnswer: '13'),
      );

      expect(gradeItem(first, '13'), Verdict.correct);
      expect(gradeItem(first, '12'), Verdict.wrong);
    });
  });

  group('what it refuses', () {
    Map<String, dynamic> without(String key) {
      final Map<String, dynamic> content = shippedContent()..remove(key);
      return content;
    }

    Pack read(Map<String, dynamic> content) => readIssuedPack(
          content,
          packId: 'pk_1',
          issuedAt: DateTime.utc(2026, 8, 20),
          expiresAt: DateTime.utc(2026, 9, 20),
        );

    test('a pack with no salt, because nothing in it could be graded', () {
      expect(() => read(without('pack_salt')), throwsFormatException);
    });

    test('a pack with no items', () {
      expect(() => read(without('items')), throwsFormatException);
    });

    test('an item with no digest', () {
      final Map<String, dynamic> content = shippedContent();
      (content['items']! as List<dynamic>)[0] = <String, dynamic>{
        'ladder_step': 1,
        'stimulus': <String, dynamic>{
          'kind': 'arithmetic',
          'payload': <String, dynamic>{
            'operator': '+',
            'left': <String, dynamic>{'num': 1, 'den': 1},
            'right': <String, dynamic>{'num': 1, 'den': 1},
          },
        },
        'answer': <String, dynamic>{'shape': 'integer'},
      };

      expect(() => read(content), throwsFormatException);
    });
  });
}
