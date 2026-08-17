import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How many items the player has been served, across every session.
///
/// One integer under one key, on the `shared_preferences` the day log already
/// uses — no new dependency, and that audit is recorded in
/// `dependency_allowlist_test.dart`.
///
/// **It has to persist or the fix is not a fix.** Advancing only within a run
/// would give a player the same five items every time they opened the app,
/// which is the behaviour this exists to end.
///
/// Anything unreadable reports zero, so a corrupt preference costs the player a
/// repeat of the first five items and never a launch. That is the same rule
/// `PrefsDayLogStore` and `OnboardingStore` follow, and the catch is broad for
/// the same reason: a key holding the wrong type throws a `TypeError`, which is
/// an `Error` and not an `Exception`.
class SeriesCursorStore {
  const SeriesCursorStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  static const String key = 'akimath.items_served.v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs => _preferences ?? SharedPreferencesAsync();

  Future<int> read() async {
    try {
      final int? served = await _prefs.getInt(key);
      // A negative stored value would make `seriesPlan` throw on the next
      // launch, turning a corrupt preference into a dead app.
      return served == null || served < 0 ? 0 : served;
    } catch (error) {
      debugPrint('series cursor: could not read ($error)');
      return 0;
    }
  }

  /// Records that `count` more items have been served, and returns the total.
  Future<int> advance(int count) async {
    final int next = await read() + (count < 0 ? 0 : count);
    try {
      await _prefs.setInt(key, next);
    } catch (error) {
      debugPrint('series cursor: could not write ($error)');
    }
    return next;
  }
}
