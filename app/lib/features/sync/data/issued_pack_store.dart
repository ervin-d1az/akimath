import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The id of the pack this device is playing.
///
/// **The id and nothing else.** The server rebuilds a pack from the row it
/// wrote plus the content that row names, byte for byte — so keeping the pack
/// itself would be keeping a hundred and sixty kilobytes that can be asked for,
/// and keeping a *copy* that could drift from the row.
///
/// Storing it is what makes a pack survive a relaunch. Without it the device
/// issued a new one every launch, which the server permits — issuing is not
/// idempotent by nature and retention sweeps what lapses — and which leaves a
/// row behind per launch per player.
///
/// The same two-sided seam `DayLogStore` has: an interface a test hands memory
/// to, and the `shared_preferences` implementation the app runs on.
abstract interface class IssuedPackStore {
  /// The id, or null if this device has never been issued one.
  ///
  /// Returns null rather than throwing on anything unreadable: the worst
  /// outcome is issuing a pack that already existed, and the worst outcome of a
  /// throw is a launch that fails.
  Future<String?> read();

  /// Remembers [packId] as the one to fetch next launch.
  Future<void> write(String packId);

  /// Forgets it, because the server says there is no such pack.
  Future<void> clear();
}

/// A store that forgets when the app closes — which is what the app did before
/// any of this, and is still correct for a test.
class InMemoryIssuedPackStore implements IssuedPackStore {
  InMemoryIssuedPackStore([this._packId]);

  String? _packId;

  @override
  Future<String?> read() async => _packId;

  @override
  Future<void> write(String packId) async => _packId = packId;

  @override
  Future<void> clear() async => _packId = null;
}

/// The device's own record.
class PrefsIssuedPackStore implements IssuedPackStore {
  const PrefsIssuedPackStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  static const String key = 'akimath.issued_pack.v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs => _preferences ?? SharedPreferencesAsync();

  @override
  Future<String?> read() async {
    try {
      final String? stored = await _prefs.getString(key);
      return stored == null || stored.isEmpty ? null : stored;
    } catch (error) {
      // **Deliberately broad.** A key holding the wrong type throws a
      // `TypeError`, which is an `Error` and not an `Exception` — so
      // `on Exception` misses it and a launch dies on a corrupt preference.
      debugPrint('issued pack: could not read ($error)');
      return null;
    }
  }

  @override
  Future<void> write(String packId) async {
    try {
      await _prefs.setString(key, packId);
    } catch (error) {
      debugPrint('issued pack: could not write ($error)');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _prefs.remove(key);
    } catch (error) {
      debugPrint('issued pack: could not clear ($error)');
    }
  }
}
