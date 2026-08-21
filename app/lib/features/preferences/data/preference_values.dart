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

  Future<bool?> boolAt(String key) => _read<bool>(key, _prefs.getBool);

  Future<int?> intAt(String key) => _read<int>(key, _prefs.getInt);

  Future<String?> stringAt(String key) => _read<String>(key, _prefs.getString);

  Future<void> putBool(String key, {required bool value}) =>
      _write(key, () => _prefs.setBool(key, value));

  Future<void> putInt(String key, int value) =>
      _write(key, () => _prefs.setInt(key, value));

  Future<void> putString(String key, String value) =>
      _write(key, () => _prefs.setString(key, value));

  Future<T?> _read<T>(String key, Future<T?> Function(String) get) async {
    try {
      return await get(key);
    } catch (error) {
      debugPrint('settings: could not read $key ($error)');
      return null;
    }
  }

  Future<void> _write(String key, Future<void> Function() put) async {
    try {
      await put();
    } catch (error) {
      // A store that cannot persist must not look like one that can. Silence
      // here cost an afternoon once already, on the day log.
      debugPrint('settings: could not write $key ($error)');
    }
  }
}
