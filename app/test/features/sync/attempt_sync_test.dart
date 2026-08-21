import 'dart:math';

import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/api/sync.dart';
import 'package:akimath_app/features/account/policy/player_id.dart';
import 'package:akimath_app/features/sync/attempt_sync.dart';
import 'package:akimath_app/features/sync/data/attempt_journal_store.dart';
import 'package:akimath_app/features/sync/policy/attempt_journal.dart';
import 'package:flutter_test/flutter_test.dart';

/// The writer the journal never had, and the send it never had either.
///
/// `attempt_journal.dart` and its store landed with the client half of the
/// offline loop and **nothing called either**, so the server's endpoints were
/// unreachable from actual play and `HISTORIAL` could never fill. This is what
/// calls them.
class _Recorder {
  final List<List<AttemptSubmission>> batches = <List<AttemptSubmission>>[];
  SyncResult answer = const SyncDone(<AttemptVerdict>[]);

  Future<SyncResult> submit({
    required String accessToken,
    required List<AttemptSubmission> attempts,
  }) async {
    batches.add(attempts);
    return answer;
  }
}

void main() {
  late InMemoryAttemptJournalStore store;
  late _Recorder server;
  late AttemptSync sync;

  setUp(() {
    store = InMemoryAttemptJournalStore();
    server = _Recorder();
    sync = AttemptSync(
      store: store,
      submit: server.submit,
      random: Random(7),
    );
  });

  DateTime at(int minute) => DateTime.utc(2026, 8, 20, 18, minute);

  group('what gets remembered', () {
    test('an issued item is journalled by its address', () async {
      await sync.record(
        itemId: 'pk_1#7',
        sessionId: 'sesión',
        answer: '13',
        at: at(0),
        elapsed: const Duration(seconds: 4),
      );

      final List<JournalledAttempt> held = await store.read();
      expect(held, hasLength(1));
      expect(held.single.packId, 'pk_1');
      expect(held.single.index, 7);
      expect(held.single.answer, '13');
    });

    test('an authored item is dropped, without complaint', () async {
      // The bundled pack's items have no `(packId, index)` — nothing on the
      // server addresses them — so journalling one would file a batch that can
      // only ever come back a 404.
      await sync.record(
        itemId: 'add-1',
        sessionId: 'sesión',
        answer: '13',
        at: at(0),
        elapsed: const Duration(seconds: 4),
      );

      expect(await store.read(), isEmpty);
    });

    test('answering the same item again keeps the later answer', () async {
      for (final String answer in <String>['12', '13']) {
        await sync.record(
          itemId: 'pk_1#7',
          sessionId: 'sesión',
          answer: answer,
          at: at(0),
          elapsed: const Duration(seconds: 4),
        );
      }

      final List<JournalledAttempt> held = await store.read();
      expect(held, hasLength(1));
      expect(held.single.answer, '13');
    });

    test('a negative elapsed is clamped rather than sent', () async {
      // `AttemptSubmission` asserts on one, and a clock that went backwards
      // between two reads should not cost a player their answer.
      await sync.record(
        itemId: 'pk_1#7',
        sessionId: 'sesión',
        answer: '13',
        at: at(0),
        elapsed: const Duration(seconds: -4),
      );

      expect((await store.read()).single.elapsed, Duration.zero);
    });

    test('the moment is stored in UTC', () async {
      await sync.record(
        itemId: 'pk_1#7',
        sessionId: 'sesión',
        answer: '13',
        at: DateTime(2026, 8, 20, 18),
        elapsed: Duration.zero,
      );

      expect((await store.read()).single.at.isUtc, isTrue);
    });
  });

  group('a session id', () {
    test('is a version 4 uuid, because the frozen schema pins one', () {
      final String id = sync.newSessionId();

      expect(isPlayerId(id), isTrue, reason: id);
    });

    test('and two sittings do not share one', () {
      expect(sync.newSessionId(), isNot(sync.newSessionId()));
    });
  });

  group('what gets sent', () {
    Future<void> journalOne({String item = 'pk_1#7', String answer = '13'}) =>
        sync.record(
          itemId: item,
          sessionId: 'sesión',
          answer: answer,
          at: at(0),
          elapsed: const Duration(seconds: 4),
        );

    test('nothing, when there is nothing — and that is not a failure', () async {
      expect(await sync.flush('token'), isNull);
      expect(server.batches, isEmpty);
    });

    test('the whole journal, as pack references', () async {
      await journalOne();
      await journalOne(item: 'pk_1#8', answer: '20');

      await sync.flush('token');

      expect(server.batches, hasLength(1));
      final List<AttemptSubmission> sent = server.batches.single;
      expect(sent, hasLength(2));
      expect(sent.first.packRef?.packId, 'pk_1');
      expect(sent.first.itemId, isNull);
    });

    test('and no verdict travels with it', () async {
      // The frozen schema has nowhere to put one, and the server regrades from
      // the same inputs anyway.
      await journalOne();
      await sync.flush('token');

      expect(server.batches.single.single.toJson().containsKey('ok'), isFalse);
    });

    test('a batch that landed leaves the journal', () async {
      await journalOne();
      server.answer = const SyncDone(<AttemptVerdict>[]);

      await sync.flush('token');

      expect(await store.read(), isEmpty);
    });

    test('a malformed batch is dropped, because resending it is forever', () async {
      await journalOne();
      server.answer = const SyncMalformed('no se pudo leer el lote');

      await sync.flush('token');

      expect(await store.read(), isEmpty);
    });

    test('an unreachable server keeps it, which is what the journal is for',
        () async {
      await journalOne();
      server.answer = const SyncUnreachable('sin red');

      await sync.flush('token');

      expect(await store.read(), hasLength(1));
    });

    test('a refused session keeps it, because the token is what is wrong',
        () async {
      await journalOne();
      server.answer = const SyncRejected(tag: 'invalid_session', message: 'caducó');

      await sync.flush('token');

      expect(await store.read(), hasLength(1));
    });

    test('an answer given while the send was in flight survives it', () async {
      // Only what was *sent* is removed. This is the race the journal would
      // silently lose an answer to.
      await journalOne();
      final AttemptSync racing = AttemptSync(
        store: store,
        submit: ({
          required String accessToken,
          required List<AttemptSubmission> attempts,
        }) async {
          await sync.record(
            itemId: 'pk_1#9',
            sessionId: 'sesión',
            answer: '5',
            at: at(1),
            elapsed: const Duration(seconds: 2),
          );
          return const SyncDone(<AttemptVerdict>[]);
        },
      );

      await racing.flush('token');

      final List<JournalledAttempt> left = await store.read();
      expect(left, hasLength(1));
      expect(left.single.index, 9);
    });
  });
}
