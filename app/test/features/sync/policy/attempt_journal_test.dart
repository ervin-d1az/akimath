import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/api/sync.dart';
import 'package:akimath_app/api/time_on_task.dart';
import 'package:akimath_app/features/sync/policy/attempt_journal.dart';
import 'package:flutter_test/flutter_test.dart';

const String _pack = '018f4e3c-0000-7000-8000-0000000000c1';
const String _session = '018f4e3c-0000-7000-8000-0000000000c2';

JournalledAttempt at(int index, {String answer = '13', int minute = 0}) =>
    JournalledAttempt(
      packId: _pack,
      index: index,
      sessionId: _session,
      answer: answer,
      at: DateTime.utc(2026, 8, 19, 9, minute),
      elapsed: const Duration(milliseconds: 4200),
    );

List<JournalledAttempt> journalOf(int count) =>
    List<JournalledAttempt>.generate(count, (int i) => at(i));

void main() {
  group('one answer, written down', () {
    test('it round-trips through storage', () {
      final JournalledAttempt one = at(3);
      expect(JournalledAttempt.fromJson(one.toJson()), one);
    });

    test('and a stored row that is not one is refused', () {
      for (final String absent in <String>[
        'packId',
        'index',
        'sessionId',
        'answer',
        'at',
        'elapsedMs',
      ]) {
        final Map<String, Object?> body = at(0).toJson()..remove(absent);
        expect(() => JournalledAttempt.fromJson(body), throwsFormatException, reason: absent);
      }
    });

    test('it becomes a submission naming its pack and position', () {
      // With `packId`, the position *is* the item's identity: the pack format
      // gives its items no identifier.
      final Map<String, Object?> sent = at(3).toSubmission().toJson();

      expect(sent['packRef'], <String, Object?>{'packId': _pack, 'index': 3});
      expect(sent.containsKey('itemId'), isFalse);
      expect(sent['elapsedMs'], 4200);
    });

    test('a row stored before the bound existed still sends a value in range', () {
      // **Why the ceiling is applied on the way to the wire and not on the way
      // into the journal.** `AttemptSync.record` cannot reach a row that is
      // already on a player's disk, and a device that answered an item left
      // open for an afternoon has one — written by a build with no bound at
      // all. Clamping only at record time would leave that device losing every
      // batch it ever sends, which is the whole defect.
      final JournalledAttempt legacy = JournalledAttempt.fromJson(<String, Object?>{
        'packId': _pack,
        'index': 3,
        'sessionId': _session,
        'answer': '13',
        'at': '2026-08-19T09:00:00.000Z',
        'elapsedMs': 12000000,
      });

      expect(legacy.elapsed, const Duration(milliseconds: 12000000),
          reason: 'the journal keeps what it was given; only the wire is bounded');
      expect(
        legacy.toSubmission().toJson()['elapsedMs'],
        maxReportableTimeOnTask.inMilliseconds,
      );
    });

    test('and it carries no verdict, because the server decides that', () {
      // Kept on this side too, so a future screen cannot start reading a local
      // verdict and quietly diverge from the recorded one.
      expect(at(0).toJson().containsKey('ok'), isFalse);
      expect(at(0).toSubmission().toJson().containsKey('ok'), isFalse);
    });
  });

  group('adding to the journal', () {
    test('a new item is appended', () {
      expect(journalWith(journalOf(2), at(2)).map((JournalledAttempt a) => a.index),
          <int>[0, 1, 2]);
    });

    test('the same item twice keeps the later answer', () {
      // A player who replays an item before syncing has answered it twice and
      // the server will keep one. The later of the two is what they last did.
      final List<JournalledAttempt> after =
          journalWith(journalOf(3), at(1, answer: 'otra', minute: 9));

      expect(after, hasLength(3));
      expect(after.map((JournalledAttempt a) => a.index), <int>[0, 2, 1]);
      expect(after.last.answer, 'otra');
    });

    test('and it never grows past what one batch can carry', () {
      // The server refuses more than two hundred in a request, so a journal
      // past that could never be flushed: every sync would 400 and the backlog
      // would grow for ever.
      List<JournalledAttempt> journal = journalOf(journalLimit);
      journal = journalWith(journal, at(journalLimit));

      expect(journal, hasLength(journalLimit));
      // The oldest goes: a recent answer is the one a player is waiting to see
      // counted.
      expect(journal.first.index, 1);
      expect(journal.last.index, journalLimit);
    });
  });

  group('what is left after a sync', () {
    final List<JournalledAttempt> sent = journalOf(3);

    test('a batch that landed is gone, wrong answers included', () {
      // "Wrong" is a recorded answer, not a failed send.
      final SyncResult done = SyncDone(<AttemptVerdict>[
        const AttemptVerdict(ok: false, payload: <String, Object?>{}),
      ]);

      expect(journalAfter(sent, sent, done), isEmpty);
    });

    test('a batch the server could not read is dropped', () {
      // Resending a malformed one resends it for ever, and the answers in it
      // are already unrecoverable.
      expect(journalAfter(sent, sent, const SyncMalformed('bad')), isEmpty);
      expect(
        journalAfter(sent, sent, const SyncNoSuchItem(tag: 'no_such_item', message: '')),
        isEmpty,
      );
    });

    test('but a refused session keeps the work', () {
      // The token is what is wrong, not what the player did.
      expect(
        journalAfter(sent, sent, const SyncRejected(tag: 'invalid_session', message: '')),
        hasLength(3),
      );
    });

    test('and so does no answer at all, which is what it is for', () {
      expect(journalAfter(sent, sent, const SyncUnreachable('no route')), hasLength(3));
      expect(journalAfter(sent, sent, const SyncFailed(status: 500, reason: '')), hasLength(3));
    });

    test('only what was sent is removed', () {
      // A player who answered another item while the request was in flight has
      // an entry the server has never seen.
      final List<JournalledAttempt> journal = <JournalledAttempt>[...sent, at(9)];

      final List<JournalledAttempt> after =
          journalAfter(sent, journal, const SyncDone(<AttemptVerdict>[]));

      expect(after.map((JournalledAttempt a) => a.index), <int>[9]);
    });

    test('and every result is decided one way or the other', () {
      // The control: a case added later has to be classified, and this fails if
      // the switch grows a default instead.
      final List<SyncResult> every = <SyncResult>[
        const SyncDone(<AttemptVerdict>[]),
        const SyncMalformed(''),
        const SyncNoSuchItem(tag: '', message: ''),
        const SyncRejected(tag: '', message: ''),
        const SyncFailed(status: 0, reason: ''),
        const SyncUnreachable(''),
      ];
      final Set<int> outcomes =
          every.map((SyncResult r) => journalAfter(sent, sent, r).length).toSet();

      expect(outcomes, <int>{0, 3});
    });
  });
}
