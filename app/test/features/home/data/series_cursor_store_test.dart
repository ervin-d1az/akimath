import 'package:akimath_app/features/home/data/series_cursor_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _brokenStorageTests();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('the cursor survives a relaunch', () {
    test('a fresh install has served nothing', () async {
      expect(await const SeriesCursorStore().read(), 0);
    });

    test('what one store advances, another reads', () async {
      // Two instances over one backend is what a relaunch looks like from here,
      // and persistence is the whole point: advancing only within a run would
      // give the same five items every time the app opened.
      await const SeriesCursorStore().advance(5);
      expect(await const SeriesCursorStore().read(), 5);

      await const SeriesCursorStore().advance(5);
      expect(await const SeriesCursorStore().read(), 10);
    });

    test('advance reports the new total', () async {
      expect(await const SeriesCursorStore().advance(5), 5);
      expect(await const SeriesCursorStore().advance(3), 8);
    });
  });

  group('a corrupt cursor costs a repeat, never a launch', () {
    test('a wrongly-typed key reads as zero', () async {
      await SharedPreferencesAsync().setString(SeriesCursorStore.key, 'lots');
      expect(await const SeriesCursorStore().read(), 0);
    });

    test('a negative stored value reads as zero', () async {
      // `seriesPlan` refuses a negative offset, so a negative here would turn a
      // corrupt preference into a dead app rather than a repeated series.
      await SharedPreferencesAsync().setInt(SeriesCursorStore.key, -7);
      expect(await const SeriesCursorStore().read(), 0);
    });

    test('a negative advance does not rewind the cursor', () async {
      await const SeriesCursorStore().advance(5);
      expect(await const SeriesCursorStore().advance(-3), 5);
    });
  });
}

/// A backend whose every operation throws.
base class _BrokenBackend extends SharedPreferencesAsyncPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('storage unavailable');
}

void _brokenStorageTests() {
  group('storage that fails outright costs a repeat, never a launch', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance = _BrokenBackend();
    });

    test('a failing read reports zero', () async {
      expect(await const SeriesCursorStore().read(), 0);
    });

    test('a failing write does not throw', () async {
      await expectLater(const SeriesCursorStore().advance(5), completes);
    });
  });
}
