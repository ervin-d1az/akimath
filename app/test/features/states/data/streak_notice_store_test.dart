import 'package:akimath_app/features/states/data/streak_notice_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the in-memory record', () {
    test('starts empty and keeps only the day', () async {
      final InMemoryStreakNoticeStore store = InMemoryStreakNoticeStore();
      expect(await store.lostShownOn(), isNull);

      await store.markLostShown(DateTime(2026, 8, 20, 20, 14));
      expect(await store.lostShownOn(), DateTime(2026, 8, 20));
    });
  });

  group('the device record', () {
    setUp(() => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty());

    test('a day written is a day read back', () async {
      const PrefsStreakNoticeStore store = PrefsStreakNoticeStore();
      await store.markLostShown(DateTime(2026, 8, 20, 20, 14));

      expect(await store.lostShownOn(), DateTime(2026, 8, 20));
    });

    test('what it writes carries no time of day', () async {
      // The same privacy reading `DayLog` is built on: what hour a player
      // opened the app is not needed to show a screen once.
      const PrefsStreakNoticeStore store = PrefsStreakNoticeStore();
      await store.markLostShown(DateTime(2026, 8, 20, 20, 14));

      final String? raw =
          await SharedPreferencesAsync().getString(PrefsStreakNoticeStore.key);
      expect(raw, '2026-08-20');
      expect(raw, isNot(contains(':')));
    });

    test('nothing stored reads as never shown', () async {
      expect(await const PrefsStreakNoticeStore().lostShownOn(), isNull);
    });

    test('an unparseable value reads as never shown, not as a crash', () async {
      await SharedPreferencesAsync()
          .setString(PrefsStreakNoticeStore.key, 'ayer por la tarde');

      expect(await const PrefsStreakNoticeStore().lostShownOn(), isNull);
    });

    test('a date that never existed is refused', () async {
      // `DateTime.tryParse` rolls `2026-13-45` into February 2027 rather than
      // refusing it. Round-tripping the format is what catches that.
      await SharedPreferencesAsync()
          .setString(PrefsStreakNoticeStore.key, '2026-13-45');

      expect(await const PrefsStreakNoticeStore().lostShownOn(), isNull);
    });

    test('a value of the wrong type does not kill the launch', () async {
      // A `TypeError` is an `Error`, not an `Exception`, which is why the
      // catch is deliberately broad.
      await SharedPreferencesAsync().setBool(PrefsStreakNoticeStore.key, true);

      expect(await const PrefsStreakNoticeStore().lostShownOn(), isNull);
    });
  });
}
