import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/data/prefs_day_log_store.dart';
import 'package:akimath_app/features/home/policy/day_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

DateTime day(int y, int m, int d) => DateTime(y, m, d);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The in-memory backend the plugin ships for tests. It is the real
    // SharedPreferencesAsync API over a fake store, so the adapter under test
    // is exercised rather than mocked out.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('the log survives a new store over the same storage', () {
    test('what one store writes, another reads', () async {
      // Two instances over one backend is what a relaunch looks like from the
      // adapter's side.
      await const PrefsDayLogStore().record(day(2026, 8, 15));
      await const PrefsDayLogStore().record(day(2026, 8, 16));

      final DayLog reread = await const PrefsDayLogStore().read();
      expect(reread.days, <DateTime>[day(2026, 8, 15), day(2026, 8, 16)]);
    });

    test('an empty store reads as an empty log', () async {
      expect((await const PrefsDayLogStore().read()).days, isEmpty);
    });

    test('recording twice in a day stores one day', () async {
      await const PrefsDayLogStore().record(DateTime(2026, 8, 16, 7));
      await const PrefsDayLogStore().record(DateTime(2026, 8, 16, 19));

      expect((await const PrefsDayLogStore().read()).days, hasLength(1));
    });
  });

  group('what is written is a date and nothing more', () {
    test('the stored string carries no time of day', () async {
      await const PrefsDayLogStore().record(DateTime(2026, 8, 16, 21, 47));

      final String? raw =
          await SharedPreferencesAsync().getString(PrefsDayLogStore.key);
      expect(raw, '2026-08-16');
      expect(raw, isNot(contains(':')));
    });

    test('it uses one key, named for what it holds', () async {
      await const PrefsDayLogStore().record(day(2026, 8, 16));

      final Set<String> keys = await SharedPreferencesAsync().getKeys();
      expect(keys, <String>{PrefsDayLogStore.key});
    });
  });

  group('corrupt storage costs the streak, never the launch', () {
    test('junk in the key reads as an empty log', () async {
      await SharedPreferencesAsync()
          .setString(PrefsDayLogStore.key, 'not a log at all');

      expect((await const PrefsDayLogStore().read()).days, isEmpty);
    });

    test('recording over junk replaces it with a valid log', () async {
      await SharedPreferencesAsync()
          .setString(PrefsDayLogStore.key, 'not a log at all');

      final DayLog after = await const PrefsDayLogStore().record(day(2026, 8, 16));
      expect(after.days, <DateTime>[day(2026, 8, 16)]);
      expect((await const PrefsDayLogStore().read()).days, hasLength(1));
    });
  });

  group('it satisfies the seam', () {
    test('a DayLogStore is what the app holds', () async {
      const DayLogStore store = PrefsDayLogStore();
      await store.record(day(2026, 8, 16));

      expect((await store.read()).days, hasLength(1));
    });
  });

  group('a wrongly-typed key costs the streak, never the launch', () {
    // A `TypeError` is an `Error`, not an `Exception`, so `on Exception` misses
    // it — and a launch dies on a corrupt preference. Found while building
    // `OnboardingStore`, which had the same narrow catch.
    test('a bool under the key reads as an empty log', () async {
      await SharedPreferencesAsync().setBool(PrefsDayLogStore.key, true);

      expect((await const PrefsDayLogStore().read()).days, isEmpty);
    });

    test('an int under the key reads as an empty log', () async {
      await SharedPreferencesAsync().setInt(PrefsDayLogStore.key, 7);

      expect((await const PrefsDayLogStore().read()).days, isEmpty);
    });

    test('recording over a wrongly-typed key repairs it', () async {
      await SharedPreferencesAsync().setBool(PrefsDayLogStore.key, true);

      final DayLog after =
          await const PrefsDayLogStore().record(day(2026, 8, 17));

      expect(after.days, <DateTime>[day(2026, 8, 17)]);
      expect((await const PrefsDayLogStore().read()).days, hasLength(1));
    });
  });
}
