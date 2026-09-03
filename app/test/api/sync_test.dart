import 'package:akimath_app/api/sync.dart';
import 'package:akimath_app/api/time_on_task.dart';
import 'package:flutter_test/flutter_test.dart';

const String _pack = '018f4e3c-0000-7000-8000-0000000000c1';
const String _session = '018f4e3c-0000-7000-8000-0000000000c2';
const String _item = '018f4e3c-0000-7000-8000-0000000000c3';

void main() {
  group('an attempt names exactly one source', () {
    test('a pack item, by pack and position', () {
      final AttemptSubmission attempt = AttemptSubmission.forPackItem(
        ref: const PackRef(packId: _pack, index: 3),
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
      final AttemptSubmission attempt = AttemptSubmission.forIssuedItem(
        itemId: _item,
        sessionId: _session,
        answer: '13',
        at: DateTime.utc(2026, 8, 19, 9, 15),
        elapsed: Duration.zero,
      );

      expect(attempt.toJson()['itemId'], _item);
      expect(attempt.toJson().containsKey('packRef'), isFalse);
    });

    test('and never neither or both, in the build a player runs', () {
      // **The compiler is the enforcement, and this is what is left to assert
      // at runtime.** Naming neither source or both is unwritable: the
      // generative constructor is private to `sync.dart` and the two public
      // doors each set the other field themselves. That half cannot be a
      // `test`, because the code expressing it does not compile — see the
      // ledger's falsification, which is a build failure rather than a red
      // case. What is checkable here is that each door leaves exactly one
      // source on the wire, which is the property the private constructor
      // exists to guarantee.
      //
      // It used to be an `assert`, and `flutter build --release` strips those:
      // every test saw a refusal no shipping binary made, and a batch naming
      // both comes back a 400, which `journalAfter` reads as a batch there is
      // no point resending — up to two hundred answers deleted in silence.
      final AttemptSubmission byPack = AttemptSubmission.forPackItem(
        ref: const PackRef(packId: _pack, index: 0),
        sessionId: _session,
        answer: '1',
        at: DateTime.utc(2026),
        elapsed: Duration.zero,
      );
      expect(byPack.packRef, isNotNull);
      expect(byPack.itemId, isNull);
      expect(byPack.toJson().containsKey('itemId'), isFalse);

      final AttemptSubmission byIssued = AttemptSubmission.forIssuedItem(
        itemId: _item,
        sessionId: _session,
        answer: '1',
        at: DateTime.utc(2026),
        elapsed: Duration.zero,
      );
      expect(byIssued.itemId, isNotNull);
      expect(byIssued.packRef, isNull);
      expect(byIssued.toJson().containsKey('packRef'), isFalse);
    });

    test('and it carries no verdict, because there is nowhere to put one', () {
      // §4's invariant. The server grades; a field here asserting the answer
      // was right is the thing the frozen schema refuses to have.
      final Map<String, Object?> body = AttemptSubmission.forPackItem(
        ref: const PackRef(packId: _pack, index: 0),
        sessionId: _session,
        answer: '13',
        at: DateTime.utc(2026),
        elapsed: Duration.zero,
      ).toJson();

      for (final String claim in <String>['ok', 'correct', 'isCorrect', 'verdict', 'score']) {
        expect(body.containsKey(claim), isFalse, reason: claim);
      }
    });

    test('time on task is milliseconds, and travels unaltered inside the bound', () {
      expect(
        AttemptSubmission.forPackItem(
          ref: const PackRef(packId: _pack, index: 0),
          sessionId: _session,
          answer: '1',
          at: DateTime.utc(2026),
          elapsed: const Duration(minutes: 1, seconds: 7),
        ).toJson()['elapsedMs'],
        67000,
      );
      // The ceiling itself is in range, so it is not clamped to something else.
      expect(
        AttemptSubmission.forPackItem(
          ref: const PackRef(packId: _pack, index: 0),
          sessionId: _session,
          answer: '1',
          at: DateTime.utc(2026),
          elapsed: maxReportableTimeOnTask,
        ).toJson()['elapsedMs'],
        maxReportableTimeOnTask.inMilliseconds,
      );
    });

    test('a negative one is floored rather than refused', () {
      // **This replaces a `throwsA(isA<AssertionError>())`, it does not delete
      // it.** The assert was stripped by `flutter build --release`, so the
      // guarantee it advertised held in every test and in no shipping binary
      // (TYP-2). Losing the last test of an invariant on the way to
      // strengthening it is the PROC-11 regression that rule warns about.
      expect(
        AttemptSubmission.forPackItem(
          ref: const PackRef(packId: _pack, index: 0),
          sessionId: _session,
          answer: '1',
          at: DateTime.utc(2026),
          elapsed: const Duration(milliseconds: -1),
        ).toJson()['elapsedMs'],
        0,
      );
    });

    test('and one measured past the bound saturates at it', () {
      // An item left open for an afternoon — a phone in a pocket, a call
      // taken. Before 2026-09-02 this sent 12_000_000, the server refused the
      // whole body with a 400, and `journalAfter` read that as a batch to drop:
      // up to two hundred real answers deleted over one timer.
      expect(
        AttemptSubmission.forPackItem(
          ref: const PackRef(packId: _pack, index: 0),
          sessionId: _session,
          answer: '1',
          at: DateTime.utc(2026),
          elapsed: const Duration(hours: 3, minutes: 20),
        ).toJson()['elapsedMs'],
        maxReportableTimeOnTask.inMilliseconds,
      );
    });

    test('the instant is UTC on the wire whatever the device says', () {
      // The server pins `date-time` to a literal `Z`. A local instant would
      // round-trip to different bytes and the two would stop agreeing.
      final Map<String, Object?> body = AttemptSubmission.forPackItem(
        ref: const PackRef(packId: _pack, index: 0),
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
