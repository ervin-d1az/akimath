import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The day `Racha perdida` was last shown.
///
/// **A seam with two sides**, the same shape `DayLogStore` has: the interface
/// so a test can hand in memory, and the `shared_preferences` implementation
/// the app runs on. No new dependency — the audit for that one is recorded in
/// `dependency_allowlist_test.dart`.
///
/// **A day, never a moment.** What hour a player opened the app is not needed
/// to show a screen once, so it is not stored — the same privacy reading
/// `DayLog` is built on, and the encoded form carries no `:` for the same
/// reason.
///
/// There is deliberately no record for `Racha en riesgo`: that screen is
/// owed on every launch of a day that is still at risk, so storing anything
/// about it would be storing a fact nobody reads.
abstract interface class StreakNoticeStore {
  /// The day the page-turn screen was last shown, or null if it never was.
  ///
  /// Returns null rather than throwing when the value is missing or unreadable:
  /// the worst outcome of an unreadable record is the screen appearing a second
  /// time, and the worst outcome of a throw is a launch that fails.
  Future<DateTime?> lostShownOn();

  /// Records that it was shown on the day [moment] falls on.
  Future<void> markLostShown(DateTime moment);
}

/// A store that forgets when the app closes.
///
/// Not a stub: it is the correct implementation of "remember within a session",
/// and what it costs when it forgets is one extra page turn.
class InMemoryStreakNoticeStore implements StreakNoticeStore {
  InMemoryStreakNoticeStore([this._shown]);

  DateTime? _shown;

  @override
  Future<DateTime?> lostShownOn() async => _shown;

  @override
  Future<void> markLostShown(DateTime moment) async {
    _shown = DateTime(moment.year, moment.month, moment.day);
  }
}

/// The device's own record.
class PrefsStreakNoticeStore implements StreakNoticeStore {
  const PrefsStreakNoticeStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  static const String key = 'akimath.streak_lost_shown.v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs =>
      _preferences ?? SharedPreferencesAsync();

  @override
  Future<DateTime?> lostShownOn() async {
    try {
      final String? stored = await _prefs.getString(key);
      if (stored == null) {
        return null;
      }
      final DateTime? parsed = DateTime.tryParse(stored);
      // **Round-tripping is what rejects a date that never existed.**
      // `tryParse` is lenient about out-of-range components: `2026-13-45`
      // parses, rolling into February 2027. `DayLog.decode` guards the same way
      // and for the same reason.
      return parsed != null && _formatDay(parsed) == stored ? parsed : null;
    } catch (error) {
      // **Deliberately broad.** A key holding the wrong type throws a
      // `TypeError`, which is an `Error` and not an `Exception` — so
      // `on Exception` misses it and a launch dies on a corrupt preference.
      // Reported rather than swallowed: a tolerant adapter must still be a
      // loud one.
      debugPrint('streak notice: could not read ($error)');
      return null;
    }
  }

  @override
  Future<void> markLostShown(DateTime moment) async {
    try {
      await _prefs.setString(key, _formatDay(moment));
    } catch (error) {
      debugPrint('streak notice: could not write ($error)');
    }
  }

  static String _formatDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
