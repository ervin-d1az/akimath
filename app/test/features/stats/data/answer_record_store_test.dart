import 'dart:convert';

import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/features/stats/data/answer_record_store.dart';
import 'package:akimath_app/features/stats/policy/local_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

AnsweredItem _right([int ms = 4200]) =>
    AnsweredItem(verdict: Verdict.correct, elapsed: Duration(milliseconds: ms));

AnsweredItem _wrong([int ms = 9100]) =>
    AnsweredItem(verdict: Verdict.wrong, elapsed: Duration(milliseconds: ms));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the in-memory record', () {
    test('hands back what it was given, and a copy of it', () async {
      final InMemoryAnswerRecordStore store =
          InMemoryAnswerRecordStore(<AnsweredItem>[_right(), _wrong()]);

      final List<AnsweredItem> read = await store.read();
      read.clear();

      expect(await store.read(), hasLength(2));
    });

    test('recording returns the record it just wrote', () async {
      // A caller that has just recorded should not have to read again to draw
      // the new figure — that second await is where a stale screen comes from.
      final InMemoryAnswerRecordStore store = InMemoryAnswerRecordStore();

      expect(await store.record(_right()), <AnsweredItem>[_right()]);
      expect(await store.read(), <AnsweredItem>[_right()]);
    });
  });

  group('the record on the device', () {
    setUp(() => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty());

    test('an answer survives being written and read', () async {
      const PrefsAnswerRecordStore store = PrefsAnswerRecordStore();
      await store.record(_right());
      await store.record(_wrong());

      expect(await store.read(), <AnsweredItem>[_right(), _wrong()]);
    });

    test('nothing stored is an empty record, not a failure', () async {
      expect(await const PrefsAnswerRecordStore().read(), isEmpty);
    });

    test('a stored record is trimmed to the window as it is written', () async {
      // The adapter holds no arithmetic of its own — it calls `recordedWith`.
      // Asserted here because a store that appended for ever would look correct
      // for months and then read a megabyte on the launch path.
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(<String, Object>{
        PrefsAnswerRecordStore.key: json.encode(<Object?>[
          for (int at = 0; at < answersKept; at++) _right(at).toJson(),
        ]),
      });

      final List<AnsweredItem> after =
          await const PrefsAnswerRecordStore().record(_wrong(1));

      expect(after, hasLength(answersKept));
      expect(after.last, _wrong(1));
      expect(after.first, _right(1));
    });

    test('an unreadable row is dropped and the rest are kept', () async {
      // Losing a whole record to one bad row is worse than losing the row: the
      // rows are independent, and the figures are an average over what is left.
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(<String, Object>{
        PrefsAnswerRecordStore.key: json.encode(<Object?>[
          _right().toJson(),
          <String, Object?>{'verdict': 'skipped', 'elapsedMs': 10},
          _wrong().toJson(),
        ]),
      });

      expect(
        await const PrefsAnswerRecordStore().read(),
        <AnsweredItem>[_right(), _wrong()],
      );
    });

    test('a value that is not a JSON array reads as empty', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(<String, Object>{
        PrefsAnswerRecordStore.key: '{"answered":7}',
      });

      expect(await const PrefsAnswerRecordStore().read(), isEmpty);
    });

    test('a key holding the wrong type costs no launch', () async {
      // Deliberately broad, the same as `PrefsAttemptJournalStore`: an int
      // under a string key throws a `TypeError`, which is an `Error` and not an
      // `Exception`, so `on Exception` would let it kill the launch.
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(<String, Object>{
        PrefsAnswerRecordStore.key: 7,
      });

      expect(await const PrefsAnswerRecordStore().read(), isEmpty);
    });

    test('a corrupt record does not stop the next answer being recorded',
        () async {
      // The failure mode that matters: a player whose preference went bad once
      // should start counting again, not be stuck at "no figures" for ever.
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(<String, Object>{
        PrefsAnswerRecordStore.key: 'not json at all',
      });

      expect(
        await const PrefsAnswerRecordStore().record(_right()),
        <AnsweredItem>[_right()],
      );
    });
  });

  group('what the store adds up to', () {
    setUp(() => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty());

    test('a device that has never played reports absent figures', () async {
      final LocalStats stats =
          LocalStats.of(await const PrefsAnswerRecordStore().read());

      expect(stats.accuracyPercent, isNull);
      expect(stats.meanTime, isNull);
    });

    test('three rights and one wrong is 75% and the mean of the four',
        () async {
      const PrefsAnswerRecordStore store = PrefsAnswerRecordStore();
      await store.record(_right(4000));
      await store.record(_right(6000));
      await store.record(_right(8000));
      await store.record(_wrong(2000));

      final LocalStats stats = LocalStats.of(await store.read());

      expect(stats.accuracyPercent, 75);
      expect(stats.meanTime, const Duration(milliseconds: 5000));
    });
  });
}
