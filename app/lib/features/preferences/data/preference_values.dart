import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one place a settings screen touches the device's storage.
///
/// **ADAPTER, and the only home of the swallow.** Eleven keys across three
/// screens would otherwise be eleven `try`/`catch` blocks, and the one written
/// differently is the one that takes a launch down. Every read answers `null`
/// on anything it cannot make sense of, and every write reports rather than
/// disappears.
///
/// The catch is **deliberately broad**, for the reason `PrefsDayLogStore`
/// records: a key holding the wrong type throws a `TypeError`, which is an
/// `Error` and not an `Exception`, so `on Exception` lets it through and the
/// screen dies on a corrupt preference. Nothing about a stored value may
/// prevent a screen from opening, and that is wider than the exception
/// hierarchy.
///
/// No new dependency — `shared_preferences` is the one the day log already
/// uses, and its DEP-1 audit is recorded in `dependency_allowlist_test.dart`.
class PreferenceValues {
  const PreferenceValues({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs => _preferences ?? SharedPreferencesAsync();

  Future<bool?> boolAt(String key) =>
      _read<bool>(key, (SharedPreferencesAsync prefs) => prefs.getBool(key));

  Future<int?> intAt(String key) =>
      _read<int>(key, (SharedPreferencesAsync prefs) => prefs.getInt(key));

  Future<String?> stringAt(String key) =>
      _read<String>(key, (SharedPreferencesAsync prefs) => prefs.getString(key));

  Future<void> putBool(String key, {required bool value}) => _write(
      key, (SharedPreferencesAsync prefs) => prefs.setBool(key, value));

  Future<void> putInt(String key, int value) =>
      _write(key, (SharedPreferencesAsync prefs) => prefs.setInt(key, value));

  Future<void> putString(String key, String value) =>
      _write(key, (SharedPreferencesAsync prefs) => prefs.setString(key, value));

  /// **`_prefs` is resolved *inside* the try, and that is the whole point.**
  /// `SharedPreferencesAsync()` throws from its own constructor when the
  /// platform instance is not registered — the case a device hits when the
  /// plugin did not link, which has happened here once already. Evaluating it
  /// as an argument put the throw outside the catch, so a screen that promised
  /// to fall back to its defaults died instead.
  Future<T?> _read<T>(
    String key,
    Future<T?> Function(SharedPreferencesAsync) get,
  ) async {
    try {
      return await get(_prefs);
    } catch (error) {
      debugPrint('settings: could not read $key ($error)');
      return null;
    }
  }

  Future<void> _write(
    String key,
    Future<void> Function(SharedPreferencesAsync) put,
  ) async {
    try {
      await put(_prefs);
    } catch (error) {
      // A store that cannot persist must not look like one that can. Silence
      // here cost an afternoon once already, on the day log.
      debugPrint('settings: could not write $key ($error)');
    }
  }
}
