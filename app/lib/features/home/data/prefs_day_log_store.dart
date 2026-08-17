import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../policy/day_log.dart';
import 'day_log_store.dart';

/// The day log, kept on the device between launches.
///
/// **One string under one key.** `DayLog` already encodes itself to a line of
/// ISO dates, so this adapter does no formatting of its own — it reads a string,
/// hands it to the decoder, and writes what the decoder's counterpart produced.
/// Every decision about what a log *is* stays in `policy/`.
///
/// It never throws — a streak is not worth a launch — but it does **not fail
/// silently**, and the difference cost an afternoon. An earlier version
/// swallowed storage errors without a word, so a store that could not write at
/// all was indistinguishable from one that worked: the app showed a streak of
/// zero and nothing anywhere said why. (The actual cause was CocoaPods missing,
/// so the plugin never linked.) Failures are now reported through
/// `debugPrint`, which costs nothing in release and is the difference between a
/// mystery and a message.
class PrefsDayLogStore implements DayLogStore {
  const PrefsDayLogStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  /// The one key. Named for what it holds rather than for the feature, so a
  /// later reader of the device's storage can tell what it is.
  static const String key = 'akimath.day_log.v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs =>
      _preferences ?? SharedPreferencesAsync();

  @override
  Future<DayLog> read() async {
    try {
      return DayLog.decode(await _prefs.getString(key) ?? '');
    } on Exception catch (error) {
      // A device whose storage is unavailable loses the streak, not the app —
      // but says so rather than reporting an empty log as if it were true.
      debugPrint('day log: could not read ($error)');
      return DayLog.empty;
    }
  }

  @override
  Future<DayLog> record(DateTime moment) async {
    final DayLog updated = (await read()).recording(moment);
    try {
      await _prefs.setString(key, updated.encode());
    } on Exception catch (error) {
      // The write failed. The returned value still reflects this session —
      // the same guarantee the in-memory store gives — but a store that cannot
      // persist must not look like one that can.
      debugPrint('day log: could not write ($error)');
    }
    return updated;
  }
}
