import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/api/sync.dart';
import 'package:akimath_app/features/sync/policy/attempt_journal.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which answers mean the server now holds rows it did not hold before.
///
/// **A different question from `journalAfter`'s, and its own file so nobody
/// reads one as the other.** That one asks *is there any point resending this*
/// and says no for a 400 and a 404 — where the batch reached the server and
/// **nothing was written**. Anything reading back what the server holds gets
/// exactly what it had before those two. So the emptying of the journal cannot
/// stand in for "there is something new to read", and this predicate is what
/// tells the two apart.
void main() {
  group('attemptsWereRecorded', () {
    test('a batch the server graded is recorded', () {
      expect(attemptsWereRecorded(const SyncDone(<AttemptVerdict>[])), isTrue);
    });

    test('a batch the server could not read recorded nothing', () {
      expect(attemptsWereRecorded(const SyncMalformed('bad body')), isFalse);
    });

    test('a batch naming an item nobody has recorded nothing', () {
      expect(
        attemptsWereRecorded(
          const SyncNoSuchItem(tag: 'unknown_item', message: 'index 2'),
        ),
        isFalse,
      );
    });

    test('a refused session recorded nothing', () {
      expect(
        attemptsWereRecorded(
          const SyncRejected(tag: 'unauthorized', message: 'expired'),
        ),
        isFalse,
      );
    });

    test('a server error recorded nothing', () {
      expect(
        attemptsWereRecorded(const SyncFailed(status: 500, reason: 'boom')),
        isFalse,
      );
    });

    test('an unreachable server recorded nothing', () {
      expect(attemptsWereRecorded(const SyncUnreachable('no route')), isFalse);
    });

    test('exactly one of the six answers is a recording', () {
      // The control, in the shape `journalAfter`'s own sweep uses: a case added
      // later has to be classified, and a switch that grew a `default` shows up
      // here rather than passing quietly.
      final List<SyncResult> every = <SyncResult>[
        const SyncDone(<AttemptVerdict>[]),
        const SyncMalformed(''),
        const SyncNoSuchItem(tag: '', message: ''),
        const SyncRejected(tag: '', message: ''),
        const SyncFailed(status: 0, reason: ''),
        const SyncUnreachable(''),
      ];

      expect(every.where(attemptsWereRecorded).length, 1);
    });
  });
}
