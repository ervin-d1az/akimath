import 'dart:math';

import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/api/sync.dart';
import 'package:akimath_app/features/sync/attempt_sync.dart';
import 'package:akimath_app/features/sync/data/attempt_journal_store.dart';
import 'package:akimath_app/features/sync/data/recorded_batch_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a flush leaves behind for a *reader* of the server, as opposed to for
/// the journal.
///
/// The journal's own bookkeeping is `journalAfter`'s and is covered next door.
/// This is the other half: after a batch is recorded, `GET /me/history` has
/// something it did not have, and something has to say so — measured on
/// 2026-09-02, where history was answered 116 ms before the batch landed and
/// Perfil drew no `HISTORIAL` section for a session the server held.
class _Server {
  SyncResult answer = const SyncDone(<AttemptVerdict>[]);
  int calls = 0;

  Future<SyncResult> submit({
    required String accessToken,
    required List<AttemptSubmission> attempts,
  }) async {
    calls++;
    return answer;
  }
}

void main() {
  late InMemoryAttemptJournalStore journal;
  late InMemoryRecordedBatchStore recorded;
  late _Server server;
  late AttemptSync sync;

  setUp(() {
    journal = InMemoryAttemptJournalStore();
    recorded = InMemoryRecordedBatchStore();
    server = _Server();
    sync = AttemptSync(
      store: journal,
      recordedBatches: recorded,
      submit: server.submit,
      random: Random(7),
    );
  });

  Future<void> answerOneItem() => sync.record(
        itemId: 'pk_1#3',
        sessionId: 'sesión',
        answer: '13',
        at: DateTime.utc(2026, 9, 2, 3, 51),
        elapsed: const Duration(seconds: 4),
      );

  test('a graded batch is counted, so a reader knows to look again', () async {
    await answerOneItem();

    await sync.flush('token');

    expect(await recorded.read(), 1);
  });

  test('a refused session counts nothing, so nothing re-reads on one',
      () async {
    // The no-retry rule Perfil keeps for a dead token — asking twice with one
    // gets the same refusal — holds here by construction rather than by a guard
    // on the reading side.
    await answerOneItem();
    server.answer = const SyncRejected(tag: 'unauthorized', message: 'expired');

    await sync.flush('token');

    expect(await recorded.read(), 0);
  });

  test('a batch the server could not read counts nothing', () async {
    // A 400 empties the journal — resending a malformed batch resends it for
    // ever — and writes nothing, so the two facts must not share a counter.
    await answerOneItem();
    server.answer = const SyncMalformed('unknown property');

    await sync.flush('token');

    expect(await journal.read(), isEmpty, reason: 'the batch was dropped');
    expect(await recorded.read(), 0, reason: 'and nothing was recorded');
  });

  test('a batch naming an item nobody has counts nothing', () async {
    await answerOneItem();
    server.answer =
        const SyncNoSuchItem(tag: 'unknown_item', message: 'index 3');

    await sync.flush('token');

    expect(await recorded.read(), 0);
  });

  test('an unreachable server counts nothing', () async {
    await answerOneItem();
    server.answer = const SyncUnreachable('no route to host');

    await sync.flush('token');

    expect(await recorded.read(), 0);
  });

  test('an empty journal sends nothing and counts nothing', () async {
    await sync.flush('token');

    expect(server.calls, 0);
    expect(await recorded.read(), 0);
  });

  test('two graded batches are two', () async {
    await answerOneItem();
    await sync.flush('token');
    await sync.record(
      itemId: 'pk_1#4',
      sessionId: 'sesión',
      answer: '21',
      at: DateTime.utc(2026, 9, 2, 3, 52),
      elapsed: const Duration(seconds: 4),
    );

    await sync.flush('token');

    expect(await recorded.read(), 2);
  });
}
