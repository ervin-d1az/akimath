import 'package:akimath_app/api/sync.dart';
import 'package:flutter_test/flutter_test.dart';

const String _pack = '018f4e3c-0000-7000-8000-0000000000c1';
const String _session = '018f4e3c-0000-7000-8000-0000000000c2';
const String _item = '018f4e3c-0000-7000-8000-0000000000c3';

void main() {
  group('an attempt names exactly one source', () {
    test('a pack item, by pack and position', () {
      final AttemptSubmission attempt = AttemptSubmission(
        packRef: const PackRef(packId: _pack, index: 3),
        sessionId: _session,
        answer: '13',
        at: DateTime.utc(2026, 8, 19, 9, 15),
        elapsed: const Duration(milliseconds: 4200),
      );

      expect(attempt.toJson(), <String, Object?>{
        'packRef': <String, Object?>{'packId': _pack, 'index': 3},
        'sessionId': _session,
        'answer': '13',
        'clientTs': '2026-08-19T09:15:00.000Z',
        'elapsedMs': 4200,
      });
    });

    test('or an item the server issued', () {
      final AttemptSubmission attempt = AttemptSubmission(
        itemId: _item,
        sessionId: _session,
        answer: '13',
        at: DateTime.utc(2026, 8, 19, 9, 15),
        elapsed: Duration.zero,
      );

      expect(attempt.toJson()['itemId'], _item);
      expect(attempt.toJson().containsKey('packRef'), isFalse);
    });

    test('and never neither or both', () {
      // Refused on the device rather than sent and refused by the server: a
      // 400 a player waits for is worse than a batch that never leaves.
      expect(
        () => AttemptSubmission(
          sessionId: _session,
          answer: '1',
          at: DateTime.utc(2026),
          elapsed: Duration.zero,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => AttemptSubmission(
          itemId: _item,
          packRef: const PackRef(packId: _pack, index: 0),
          sessionId: _session,
          answer: '1',
          at: DateTime.utc(2026),
          elapsed: Duration.zero,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('and it carries no verdict, because there is nowhere to put one', () {
      // §4's invariant. The server grades; a field here asserting the answer
      // was right is the thing the frozen schema refuses to have.
      final Map<String, Object?> body = AttemptSubmission(
        packRef: const PackRef(packId: _pack, index: 0),
        sessionId: _session,
        answer: '13',
        at: DateTime.utc(2026),
        elapsed: Duration.zero,
      ).toJson();

      for (final String claim in <String>['ok', 'correct', 'isCorrect', 'verdict', 'score']) {
        expect(body.containsKey(claim), isFalse, reason: claim);
      }
    });

    test('time on task is milliseconds, and never negative', () {
      expect(
        AttemptSubmission(
          packRef: const PackRef(packId: _pack, index: 0),
          sessionId: _session,
          answer: '1',
          at: DateTime.utc(2026),
          elapsed: const Duration(minutes: 1, seconds: 7),
        ).toJson()['elapsedMs'],
        67000,
      );
      expect(
        () => AttemptSubmission(
          packRef: const PackRef(packId: _pack, index: 0),
          sessionId: _session,
          answer: '1',
          at: DateTime.utc(2026),
          elapsed: const Duration(milliseconds: -1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('the instant is UTC on the wire whatever the device says', () {
      // The server pins `date-time` to a literal `Z`. A local instant would
      // round-trip to different bytes and the two would stop agreeing.
      final Map<String, Object?> body = AttemptSubmission(
        packRef: const PackRef(packId: _pack, index: 0),
        sessionId: _session,
        answer: '1',
        at: DateTime.utc(2026, 8, 19, 9, 15).toLocal(),
        elapsed: Duration.zero,
      ).toJson();

      expect(body['clientTs'], '2026-08-19T09:15:00.000Z');
    });
  });

  group('a verdict off the wire', () {
    test('echoes the pack item it graded', () {
      final AttemptVerdict verdict = AttemptVerdict.fromJson(<String, Object?>{
        'packRef': <String, Object?>{'packId': _pack, 'index': 3},
        'ok': true,
        'payload': <String, Object?>{},
      });

      expect(verdict.ok, isTrue);
      expect(verdict.packRef, const PackRef(packId: _pack, index: 3));
      expect(verdict.itemId, isNull);
    });

    test('or the issued item', () {
      final AttemptVerdict verdict = AttemptVerdict.fromJson(<String, Object?>{
        'itemId': _item,
        'ok': false,
        'payload': <String, Object?>{'misconception': 'off_by_one'},
      });

      expect(verdict.itemId, _item);
      expect(verdict.ok, isFalse);
      expect(verdict.payload['misconception'], 'off_by_one');
    });

    test('and a body that is not one is refused', () {
      for (final Map<String, Object?> body in <Map<String, Object?>>[
        <String, Object?>{'ok': true},
        <String, Object?>{'payload': <String, Object?>{}},
        <String, Object?>{'ok': 'yes', 'payload': <String, Object?>{}},
        <String, Object?>{'ok': true, 'payload': <String, Object?>{}, 'itemId': 7},
      ]) {
        expect(() => AttemptVerdict.fromJson(body), throwsFormatException, reason: '$body');
      }
    });
  });

  group('a pack the server issued', () {
    Map<String, Object?> body() => <String, Object?>{
      'packId': _pack,
      'issuedAt': '2026-08-19T09:15:00.000Z',
      'expiresAt': '2026-09-18T09:15:00.000Z',
      'pack': <String, Object?>{'pack_format_version': 1},
    };

    test('reads the id, the window and the body', () {
      final IssuedPack issued = IssuedPack.fromJson(body());

      expect(issued.packId, _pack);
      expect(issued.issuedAt, DateTime.utc(2026, 8, 19, 9, 15));
      expect(issued.expiresAt, DateTime.utc(2026, 9, 18, 9, 15));
      expect(issued.pack['pack_format_version'], 1);
    });

    test('the body is carried, not parsed', () {
      // `content/pack_reader.dart` already knows what a pack is and refuses an
      // expired or malformed one. Parsing it twice would be two answers to the
      // same question.
      expect(
        IssuedPack.fromJson(<String, Object?>{...body(), 'pack': <String, Object?>{}}).pack,
        isEmpty,
      );
    });

    test('and an instant the contract would refuse is refused here', () {
      expect(
        () => IssuedPack.fromJson(<String, Object?>{...body(), 'issuedAt': '2026-02-30T00:00:00Z'}),
        throwsFormatException,
      );
      expect(
        () => IssuedPack.fromJson(<String, Object?>{...body(), 'packId': 7}),
        throwsFormatException,
      );
    });
  });
}
