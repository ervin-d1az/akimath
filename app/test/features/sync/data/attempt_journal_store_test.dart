import 'dart:convert';

import 'package:akimath_app/features/sync/data/attempt_journal_store.dart';
import 'package:akimath_app/features/sync/policy/attempt_journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

JournalledAttempt at(int index) => JournalledAttempt(
      packId: '018f4e3c-0000-7000-8000-0000000000c1',
      index: index,
      sessionId: '018f4e3c-0000-7000-8000-0000000000c2',
      answer: '13',
      at: DateTime.utc(2026, 8, 19, 9, 15),
      elapsed: const Duration(milliseconds: 4200),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the in-memory journal', () {
    test('hands back what it was given, and a copy of it', () async {
      final InMemoryAttemptJournalStore store = InMemoryAttemptJournalStore();
      await store.write(<JournalledAttempt>[at(0), at(1)]);

      final List<JournalledAttempt> read = await store.read();
      read.clear();

      // A caller mutating what it read must not empty the store — the journal
      // is what stands between a week of answers and a restart.
      expect(await store.read(), hasLength(2));
    });
  });

  group('the journal on the device', () {
    setUp(() => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty());

    test('a journal survives being written and read', () async {
      const PrefsAttemptJournalStore store = PrefsAttemptJournalStore();
      await store.write(<JournalledAttempt>[at(0), at(3)]);

      expect(await store.read(), <JournalledAttempt>[at(0), at(3)]);
    });

    test('nothing stored is an empty journal, not a failure', () async {
      expect(await const PrefsAttemptJournalStore().read(), isEmpty);
    });

    test('an unreadable row is dropped and the rest are kept', () async {
      // Losing a whole journal to one bad entry is worse than losing the entry:
      // the server keys each attempt by its own source, so they are independent.
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(
        <String, Object>{
          PrefsAttemptJournalStore.key: json.encode(<Object?>[
            at(0).toJson(),
            <String, Object?>{'packId': 'x'},
            at(2).toJson(),
          ]),
        },
      );

      final List<JournalledAttempt> read = await const PrefsAttemptJournalStore().read();

      expect(read.map((JournalledAttempt a) => a.index), <int>[0, 2]);
    });

    test('and a key holding something else is an empty journal, not a crash', () async {
      // A `TypeError` is an `Error` and not an `Exception`, so this is the case
      // an `on Exception` would let kill the launch.
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(
        <String, Object>{PrefsAttemptJournalStore.key: 'not json at all'},
      );

      expect(await const PrefsAttemptJournalStore().read(), isEmpty);
    });

    test('writing an empty journal clears it', () async {
      const PrefsAttemptJournalStore store = PrefsAttemptJournalStore();
      await store.write(<JournalledAttempt>[at(0)]);
      await store.write(const <JournalledAttempt>[]);

      expect(await store.read(), isEmpty);
    });
  });
}
