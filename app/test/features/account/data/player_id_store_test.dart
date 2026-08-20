import 'dart:math';

import 'package:akimath_app/features/account/data/player_id_store.dart';
import 'package:akimath_app/features/account/policy/player_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() =>
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

  test('the first ask mints one, and every ask after it gives the same', () async {
    // A device that minted a fresh id on every launch would ask to link a
    // different player each time: the first succeeds and every one after is a
    // 409, because an account has one player (migration 0003).
    const PrefsPlayerIdStore store = PrefsPlayerIdStore();

    final String first = await store.readOrMint();
    expect(isPlayerId(first), isTrue);
    expect(await store.readOrMint(), first);
    // And it survives a new store, which is what a relaunch is.
    expect(await const PrefsPlayerIdStore().readOrMint(), first);
  });

  test('it is written where a later reader can find it', () async {
    final String minted = await const PrefsPlayerIdStore().readOrMint();

    expect(await SharedPreferencesAsync().getString(PrefsPlayerIdStore.key), minted);
  });

  test('a stored value that is not an id is replaced rather than sent', () async {
    // Otherwise it becomes a link request the server refuses with a 400 the
    // player can do nothing about.
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(
      <String, Object>{PrefsPlayerIdStore.key: 'from-an-older-app'},
    );

    final String minted = await const PrefsPlayerIdStore().readOrMint();

    expect(isPlayerId(minted), isTrue);
    expect(minted, isNot('from-an-older-app'));
    expect(await const PrefsPlayerIdStore().readOrMint(), minted);
  });

  test('and a key holding another type is a fresh id, not a crash', () async {
    // A `TypeError` is an `Error`, not an `Exception` — the case an
    // `on Exception` would let kill the launch.
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(
      <String, Object>{PrefsPlayerIdStore.key: 7},
    );

    expect(isPlayerId(await const PrefsPlayerIdStore().readOrMint()), isTrue);
  });

  test('two devices do not agree, even started together', () async {
    // `Random.secure()` rather than `Random()`: the seeded generator is seeded
    // from the clock, so two phones started together would mint the same id.
    final Set<String> minted = <String>{};
    for (int i = 0; i < 20; i++) {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      minted.add(await const PrefsPlayerIdStore().readOrMint());
    }
    expect(minted, hasLength(20));
  });

  test('a fixed generator makes the store testable without luck', () async {
    // The seam that lets the case above be about `Random.secure()` rather than
    // about probability.
    final PrefsPlayerIdStore store = PrefsPlayerIdStore(random: Random(1));

    expect(isPlayerId(await store.readOrMint()), isTrue);
  });

  test('the in-memory store keeps its id too', () async {
    final InMemoryPlayerIdStore store = InMemoryPlayerIdStore();

    expect(await store.readOrMint(), await store.readOrMint());
  });
}
