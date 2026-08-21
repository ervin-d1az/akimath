import 'dart:convert';

import 'package:akimath_app/features/map/data/practised_step_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the record held in memory', () {
    test('hands back what it was given, and a copy of it', () async {
      final InMemoryPractisedStepStore store =
          InMemoryPractisedStepStore(<String, int>{'numberSeries': 2});

      final Map<String, int> read = await store.read();
      read.clear();

      expect(await store.read(), <String, int>{'numberSeries': 2});
    });

    test('recording returns the record it just wrote', () async {
      final InMemoryPractisedStepStore store = InMemoryPractisedStepStore();

      expect(
        await store.record(family: 'matrix', step: 3),
        <String, int>{'matrix': 3},
      );
      expect(await store.read(), <String, int>{'matrix': 3});
    });
  });

  group('the record on the device', () {
    setUp(() => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty());

    test('a practised step survives being written and read', () async {
      const PractisedStepStore store = PrefsPractisedStepStore();
      await store.record(family: 'numberSeries', step: 2);
      await store.record(family: 'arithmetic', step: 4);

      expect(
        await store.read(),
        <String, int>{'numberSeries': 2, 'arithmetic': 4},
      );
    });

    test('nothing stored is an empty record, not a failure', () async {
      expect(await const PrefsPractisedStepStore().read(), isEmpty);
    });

    test('the harder step wins, whichever order the two arrive in', () async {
      // The adapter holds no arithmetic of its own — it calls `practisedWith`.
      // Asserted through the store because a device that overwrote instead of
      // merging would show a topic going backwards, which is the one thing this
      // record exists to prevent.
      const PractisedStepStore store = PrefsPractisedStepStore();
      await store.record(family: 'figurate', step: 4);
      await store.record(family: 'figurate', step: 1);

      expect(await store.read(), <String, int>{'figurate': 4});
    });

    test('a record that will not read costs no launch and no other topic',
        () async {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync
          .withData(<String, Object>{
        PrefsPractisedStepStore.key:
            json.encode(<String, Object>{'matrix': 3, 'analogy': 'four'}),
      });

      expect(await const PrefsPractisedStepStore().read(), <String, int>{
        'matrix': 3,
      });
    });

    test('a key holding something that is not a record reads as empty',
        () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(<String, Object>{
        PrefsPractisedStepStore.key: '[]',
      });

      expect(await const PrefsPractisedStepStore().read(), isEmpty);
    });

    test('a store that cannot write keeps answering, and says so', () async {
      // The other arm of the same catch. `PrefsDayLogStore` records why both
      // are reached: a store that could not write at all was once
      // indistinguishable from one that worked.
      SharedPreferencesAsyncPlatform.instance = _RefusingPreferences();

      expect(
        await const PrefsPractisedStepStore().record(
          family: 'matrix',
          step: 2,
        ),
        <String, int>{'matrix': 2},
      );
    });
  });
}

/// A backend whose every operation throws, so both arms of the store's catch
/// are reached by a test rather than only the happy one (PROC-11). The same
/// shape `prefs_day_log_store_test.dart` uses, and for the reason recorded
/// there: the in-memory backend never fails, so a tolerance nothing exercises
/// is a claim rather than a behaviour.
base class _RefusingPreferences extends SharedPreferencesAsyncPlatform {
  @override
  Future<String?> getString(String key, SharedPreferencesOptions o) =>
      throw StateError('storage unavailable');

  @override
  Future<void> setString(String key, String value, SharedPreferencesOptions o) =>
      throw StateError('storage unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('storage unavailable');
}
