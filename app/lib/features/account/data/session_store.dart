import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../api/auth_result.dart';
import '../../../api/me.dart';
import '../policy/session.dart';

/// Where being signed in is kept between launches.
///
/// **A seam, because the shell must be drivable by a `testWidgets`.** A widget
/// test that reached a real plugin would get a `MissingPluginException`, the
/// broad catch below would swallow it into a `debugPrint`, and the restore
/// would report *no session* while passing — PROC-11's "a `catch` no test
/// reaches", one level up.
abstract interface class SessionStore {
  /// What is stored, or null when nothing is or when what is there cannot be
  /// read. It never throws: a launch is not worth a credential.
  Future<StoredSession?> read();

  /// Keeps [session], replacing whatever was there.
  Future<void> write(StoredSession session);

  /// Deletes it. **The point of the whole change**: a manual sign-out has to
  /// leave nothing behind, and a store that could only overwrite would leave
  /// the last credential on disk for ever.
  Future<void> forget();
}

/// A session that lasts as long as the object does. For tests.
class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this._session]);

  StoredSession? _session;

  @override
  Future<StoredSession?> read() async => _session;

  @override
  Future<void> write(StoredSession session) async => _session = session;

  @override
  Future<void> forget() async => _session = null;
}

/// The session, on the device.
///
/// **One JSON object under one key**, on the `shared_preferences` the day log,
/// the series cursor, the player id and the pack id already use — no new
/// dependency, and that audit is recorded in `dependency_allowlist_test.dart`.
/// One key rather than three because the three are only meaningful together: a
/// credential with no band cannot link and a band with no credential is not a
/// session.
///
/// **It is not encrypted, and that is a decision rather than an oversight.** On
/// iOS this is `NSUserDefaults` — inside the app sandbox, covered by the
/// device's own Data Protection, and included in an unencrypted local backup.
/// The Keychain is the right home for a credential and reaching it needs a
/// plugin, which is a **DEP-1 decision a human takes** and not a session's to
/// make. Obfuscating the bytes here would be worse than storing them plainly:
/// it would read like protection and provide none.
///
/// It never throws, and it does **not** fail silently — the same rule
/// `PrefsDayLogStore` records, bought with an afternoon: a store that could not
/// write at all was indistinguishable from one that worked, and nothing
/// anywhere said why. A player whose device cannot keep the credential signs in
/// again next launch, which is exactly where they are today.
class PrefsSessionStore implements SessionStore {
  const PrefsSessionStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  /// The one key. Named for what it holds rather than for the feature, so a
  /// later reader of the device's storage can tell what it is.
  static const String key = 'akimath.session.v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs =>
      _preferences ?? SharedPreferencesAsync();

  @override
  Future<StoredSession?> read() async {
    try {
      final String? stored = await _prefs.getString(key);
      return stored == null ? null : _decode(stored);
    } catch (error) {
      // **Deliberately broad**, the same as `PrefsDayLogStore`: a key holding
      // the wrong type throws a `TypeError`, which is an `Error` and not an
      // `Exception`, so `on Exception` would let a corrupt preference kill the
      // launch. The rule is that *nothing* about a stored value may prevent a
      // launch, and that is wider than the exception hierarchy.
      debugPrint('session: could not read ($error)');
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) async {
    try {
      await _prefs.setString(key, _encode(session));
    } catch (error) {
      debugPrint('session: could not write ($error)');
    }
  }

  @override
  Future<void> forget() async {
    try {
      await _prefs.remove(key);
    } catch (error) {
      // **The failure worth naming.** A sign-out whose delete failed leaves a
      // usable credential on a device whose player asked us to drop it, and the
      // next launch signs them back in. Nothing here can fix that; saying so is
      // the difference between a mystery and a message.
      debugPrint('session: could not forget ($error)');
    }
  }

  /// Anything that is not a whole, readable session is no session.
  ///
  /// **Validated on the way out, not only on the way in.** A truncated write,
  /// a row from an older format, or a band this contract does not name would
  /// otherwise become a launch that comes up "signed in" holding something the
  /// provider will refuse. No band is ever defaulted: guessing `adult` for an
  /// unreadable value is the one mistake the band exists to prevent.
  static StoredSession? _decode(String stored) {
    final Object? decoded = json.decode(stored);
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    final Object? email = decoded[_emailField];
    final Object? band = decoded[_bandField];
    final Object? cookie = decoded[_cookieField];
    if (email is! String || band is! String || cookie is! String) {
      return null;
    }
    if (cookie.isEmpty) {
      return null;
    }
    return StoredSession(
      email: email,
      ageBand: AgeBand.fromWire(band),
      provider: AuthSession(cookie),
    );
  }

  static String _encode(StoredSession session) => json.encode(<String, Object?>{
        _emailField: session.email,
        _bandField: session.ageBand.wireName,
        _cookieField: session.provider.cookie,
      });

  static const String _emailField = 'email';
  static const String _bandField = 'age_band';
  static const String _cookieField = 'cookie';
}
