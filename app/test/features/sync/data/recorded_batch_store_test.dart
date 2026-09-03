import 'package:akimath_app/features/sync/data/recorded_batch_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// How many batches this device has had recorded, kept where a second root can
/// read it.
///
/// **Persisted rather than held in memory, because the two ends are two
/// roots.** `AttemptSync` is built by Inicio and by Mapa; Perfil is a sibling
/// under an `IndexedStack` and holds neither. `shared_preferences` is the seam
/// they already share — the same one the journal, the day log and the issued
/// pack travel through.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('a fresh install has had nothing recorded', () async {
    expect(await const PrefsRecordedBatchStore().read(), 0);
  });

  test('what one store counts, another reads — which is what a relaunch is',
      () async {
    await const PrefsRecordedBatchStore().countOne();
    await const PrefsRecordedBatchStore().countOne();

    expect(await const PrefsRecordedBatchStore().read(), 2);
  });

  test('a value of the wrong type does not kill the launch', () async {
    // A `TypeError` is an `Error`, not an `Exception`, which is why the catch
    // is deliberately broad — the same reading `PrefsIssuedPackStore` records.
    // The worst outcome of reading zero is one history request nobody needed.
    await SharedPreferencesAsync()
        .setString(PrefsRecordedBatchStore.key, 'not a number');

    expect(await const PrefsRecordedBatchStore().read(), 0);
  });

  test('a store that cannot write leaves the count where it was', () async {
    // The write arm of the same guard. PROC-11 names an unreached `catch` as an
    // assertion that holds for any input, and no in-memory backend fails — so
    // this is the only way that arm is ever executed.
    final PrefsRecordedBatchStore store =
        PrefsRecordedBatchStore(preferences: _FailingPreferences());

    await store.countOne();

    expect(await const PrefsRecordedBatchStore().read(), 0);
  });

  test('the in-memory one is the same contract', () async {
    final InMemoryRecordedBatchStore store = InMemoryRecordedBatchStore();
    expect(await store.read(), 0);

    await store.countOne();
    await store.countOne();
    expect(await store.read(), 2);
  });

  test('the in-memory one starts wherever it is told to', () async {
    // A test that needs a device with sync behind it should not have to call
    // `countOne` to get there.
    expect(await InMemoryRecordedBatchStore(7).read(), 7);
  });
}

/// A `shared_preferences` whose writes fail, which is the arm no real backend
/// in these tests reaches.
class _FailingPreferences implements SharedPreferencesAsync {
  @override
  Future<int?> getInt(String key) async => null;

  @override
  Future<void> setInt(String key, int value) async =>
      throw PlatformException(code: 'disk full');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}
