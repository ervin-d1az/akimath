import 'package:akimath_app/features/sync/data/issued_pack_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('a fresh install holds no pack', () async {
    expect(await const PrefsIssuedPackStore().read(), isNull);
  });

  test('what one store writes, another reads — which is what a relaunch is',
      () async {
    await const PrefsIssuedPackStore().write('pk_1');

    expect(await const PrefsIssuedPackStore().read(), 'pk_1');
  });

  test('clearing forgets it, because the server said there is no such pack',
      () async {
    const PrefsIssuedPackStore store = PrefsIssuedPackStore();
    await store.write('pk_1');
    await store.clear();

    expect(await store.read(), isNull);
  });

  test('an empty string is no pack, not a pack named nothing', () async {
    await SharedPreferencesAsync().setString(PrefsIssuedPackStore.key, '');

    expect(await const PrefsIssuedPackStore().read(), isNull);
  });

  test('a value of the wrong type does not kill the launch', () async {
    // A `TypeError` is an `Error`, not an `Exception`, which is why the catch
    // is deliberately broad. The worst outcome here is issuing a pack that
    // already existed.
    await SharedPreferencesAsync().setBool(PrefsIssuedPackStore.key, true);

    expect(await const PrefsIssuedPackStore().read(), isNull);
  });

  test('the in-memory one is the same contract', () async {
    final InMemoryIssuedPackStore store = InMemoryIssuedPackStore();
    expect(await store.read(), isNull);

    await store.write('pk_2');
    expect(await store.read(), 'pk_2');

    await store.clear();
    expect(await store.read(), isNull);
  });
}
