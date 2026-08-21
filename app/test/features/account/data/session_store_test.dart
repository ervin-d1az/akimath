import 'dart:convert';

import 'package:akimath_app/api/auth_result.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/account/data/session_store.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

const StoredSession _stored = StoredSession(
  email: 'alguien@ejemplo.com',
  ageBand: AgeBand.adult,
  provider: AuthSession('better-auth.session_token=abc123'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty());

  test('a device that has never signed in has nothing stored', () async {
    expect(await const PrefsSessionStore().read(), isNull);
  });

  test('what was written comes back through a store that never saw the write',
      () async {
    // **A new store object is what a relaunch is.** The one that wrote it is
    // gone with the process; the credential has to survive the object.
    await const PrefsSessionStore().write(_stored);

    expect(await const PrefsSessionStore().read(), _stored);
  });

  test('signing out deletes it rather than blanking it', () async {
    await const PrefsSessionStore().write(_stored);

    await const PrefsSessionStore().forget();

    expect(await const PrefsSessionStore().read(), isNull);
    expect(
      await SharedPreferencesAsync().getString(PrefsSessionStore.key),
      isNull,
      reason: 'the key survived the sign-out, holding whatever it held',
    );
  });

  test('signing in again replaces what was there', () async {
    await const PrefsSessionStore().write(_stored);

    const StoredSession other = StoredSession(
      email: 'otra@ejemplo.com',
      ageBand: AgeBand.thirteenToSeventeen,
      provider: AuthSession('better-auth.session_token=xyz'),
    );
    await const PrefsSessionStore().write(other);

    expect(await const PrefsSessionStore().read(), other);
  });

  test('the band survives, because linking still needs it', () async {
    // It is not read off the credential: linking is an adult's act and the
    // player need not be an adult. A restored session that had lost the band
    // could not link this device at all.
    await const PrefsSessionStore().write(const StoredSession(
      email: 'alguien@ejemplo.com',
      ageBand: AgeBand.thirteenToSeventeen,
      provider: AuthSession('s=abc'),
    ));

    expect((await const PrefsSessionStore().read())!.ageBand,
        AgeBand.thirteenToSeventeen);
  });

  group('nothing about a stored value may cost a launch', () {
    Future<void> seed(Object value) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(
        <String, Object>{PrefsSessionStore.key: value},
      );
    }

    test('a value that is not JSON reads as no session', () async {
      await seed('from-an-older-app');

      expect(await const PrefsSessionStore().read(), isNull);
    });

    test('JSON that is not an object reads as no session', () async {
      await seed('[1, 2, 3]');

      expect(await const PrefsSessionStore().read(), isNull);
    });

    test('a row missing the credential reads as no session', () async {
      // A truncated write. Coming up "signed in" with no cookie would ask the
      // provider to honour nothing and land the player in a refusal.
      await seed(json.encode(<String, Object?>{
        'email': 'alguien@ejemplo.com',
        'age_band': 'adult',
      }));

      expect(await const PrefsSessionStore().read(), isNull);
    });

    test('an empty credential reads as no session', () async {
      await seed(json.encode(<String, Object?>{
        'email': 'alguien@ejemplo.com',
        'age_band': 'adult',
        'cookie': '',
      }));

      expect(await const PrefsSessionStore().read(), isNull);
    });

    test('a band this contract does not name reads as no session', () async {
      // `AgeBand.fromWire` throws on one, and no band may ever be defaulted:
      // guessing `adult` for an unreadable value is the one mistake the band
      // exists to prevent.
      await seed(json.encode(<String, Object?>{
        'email': 'alguien@ejemplo.com',
        'age_band': 'grown_up',
        'cookie': 's=abc',
      }));

      expect(await const PrefsSessionStore().read(), isNull);
    });

    test('a key holding another type reads as no session, not a crash', () async {
      // A `TypeError` is an `Error`, not an `Exception` — the case an
      // `on Exception` would let kill the launch.
      await seed(7);

      expect(await const PrefsSessionStore().read(), isNull);
    });

    test('and a backend that throws costs neither read, write nor forget',
        () async {
      // **Both arms, exercised.** PROC-11's third instance is a `catch` no test
      // reaches, found in `PrefsDayLogStore` — where the unreached one was the
      // half the original incident was on.
      SharedPreferencesAsyncPlatform.instance = _ARefusingBackend();

      expect(await const PrefsSessionStore().read(), isNull);
      await const PrefsSessionStore().write(_stored);
      await const PrefsSessionStore().forget();
    });
  });

  group('the in-memory store', () {
    test('holds what it was handed, and lets go of it', () async {
      final InMemorySessionStore store = InMemorySessionStore();

      expect(await store.read(), isNull);
      await store.write(_stored);
      expect(await store.read(), _stored);
      await store.forget();
      expect(await store.read(), isNull);
    });

    test('can start with a session already in it, which is a relaunch', () async {
      expect(await InMemorySessionStore(_stored).read(), _stored);
    });
  });
}

/// A backend where every call fails, as a device whose storage is unavailable.
///
/// The measured cause on this project was CocoaPods missing, so the plugin
/// never linked and every call threw `MissingPluginException`.
final class _ARefusingBackend extends InMemorySharedPreferencesAsync {
  _ARefusingBackend() : super.empty();

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) =>
      Future<String?>.error(StateError('no storage on this device'));

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) =>
      Future<bool>.error(StateError('no storage on this device'));

  @override
  Future<bool> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) =>
      Future<bool>.error(StateError('no storage on this device'));
}
