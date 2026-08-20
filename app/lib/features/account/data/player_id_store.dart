import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../policy/player_id.dart';

/// The device's own player id, minted once and kept.
///
/// **Once, and kept, or it is not an identity.** A device that minted a fresh
/// id on every launch would ask the server to link a different player each
/// time — the first would succeed and every one after it would be a 409,
/// because an account has one player (migration 0003).
abstract interface class PlayerIdStore {
  /// The id, minting and storing one the first time it is asked.
  Future<String> readOrMint();
}

/// An id that lasts as long as the object does. For tests.
class InMemoryPlayerIdStore implements PlayerIdStore {
  InMemoryPlayerIdStore([this._id]);

  String? _id;

  @override
  Future<String> readOrMint() async =>
      _id ??= playerIdFrom(_randomBytes(Random.secure()));
}

/// The id, on the device.
///
/// **`Random.secure()`, not `Random()`.** A player id is not a secret, but it
/// is an identifier that ends up in a database and a predictable one lets
/// somebody guess another device's — and the seeded generator is seeded from
/// the clock, so two phones started together would agree.
///
/// It never throws. A device whose storage is unavailable gets a fresh id for
/// this launch and links again next time; the alternative is refusing to make
/// an account because a preference could not be written. It says so through
/// `debugPrint` rather than failing silently, which is the lesson
/// `PrefsDayLogStore` records.
class PrefsPlayerIdStore implements PlayerIdStore {
  const PrefsPlayerIdStore({SharedPreferencesAsync? preferences, Random? random})
      : _preferences = preferences,
        _random = random;

  /// Named for what it holds, so a later reader of the device's storage can
  /// tell what it is.
  static const String key = 'akimath.player_id.v1';

  final SharedPreferencesAsync? _preferences;
  final Random? _random;

  SharedPreferencesAsync get _prefs => _preferences ?? SharedPreferencesAsync();

  @override
  Future<String> readOrMint() async {
    try {
      final String? stored = await _prefs.getString(key);
      // **Validated on the way out, not only on the way in.** A key holding an
      // old format or a truncated write would otherwise become a link request
      // the server refuses with a 400 the player can do nothing about.
      if (stored != null && isPlayerId(stored)) {
        return stored;
      }
      if (stored != null) {
        debugPrint('akimath: the stored player id is not one; minting another');
      }
      final String minted = playerIdFrom(_randomBytes(_random ?? Random.secure()));
      await _prefs.setString(key, minted);
      return minted;
    } catch (error) {
      // Deliberately broad, the same as `PrefsDayLogStore`: a key holding the
      // wrong type throws a `TypeError`, which is an `Error` and not an
      // `Exception`.
      debugPrint('akimath: could not read or write the player id — $error');
      return playerIdFrom(_randomBytes(_random ?? Random.secure()));
    }
  }
}

List<int> _randomBytes(Random random) =>
    List<int>.generate(16, (_) => random.nextInt(256));
