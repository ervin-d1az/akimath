import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../policy/practised_steps.dart';

/// Where the ladder steps a practice run served live between launches.
///
/// **A seam, because a topic's progress is about more than one sitting.** The
/// map is the screen that reports how far a player has come; a figure that
/// reset on relaunch would be a different number with the same label.
///
/// The same two-sided shape `DayLogStore` and `AnswerRecordStore` have: an
/// interface a widget test hands memory to, and the `shared_preferences`
/// implementation the app runs on.
abstract interface class PractisedStepStore {
  /// The record as it stands, keyed by `familyKey`. Returns an empty record
  /// rather than throwing when there is nothing to read or what is there cannot
  /// be read — the worst outcome is a topic reading lower than it should, and
  /// the worst outcome of a throw is a launch that fails.
  Future<Map<String, int>> read();

  /// Remembers that [family] has been practised as far as [step], and returns
  /// the record it wrote.
  ///
  /// It returns rather than voids for `AnswerRecordStore.record`'s reason: a
  /// caller that has just recorded can draw the new figure without a second
  /// read, and that second await is where a stale screen comes from.
  Future<Map<String, int>> record({
    required String family,
    required int step,
  });
}

/// A record that forgets when the app closes.
///
/// Not a stub — it is the right implementation of "remember within a session",
/// and it is what a widget test uses so a pumped screen never touches a plugin.
class InMemoryPractisedStepStore implements PractisedStepStore {
  InMemoryPractisedStepStore([
    Map<String, int> initial = const <String, int>{},
  ]) : _record = Map<String, int>.of(initial);

  Map<String, int> _record;

  @override
  Future<Map<String, int>> read() async => Map<String, int>.of(_record);

  @override
  Future<Map<String, int>> record({
    required String family,
    required int step,
  }) async {
    _record = practisedWith(_record, family: family, step: step);
    return Map<String, int>.of(_record);
  }
}

/// The record, kept on the device.
///
/// **One key, one JSON object**, on the `shared_preferences` the day log, the
/// series cursor and the answer record already use — no new dependency, and
/// that audit is recorded in `dependency_allowlist_test.dart`.
///
/// **It holds no arithmetic.** Which step wins is `practisedWith`'s and what a
/// stored row means is `readPractisedSteps`'s; this translates and nothing else
/// (PURE-2).
///
/// It never throws — a map percentage is not worth a launch — but it does not
/// fail silently either, for the reason `PrefsDayLogStore` records: a store that
/// could not write at all was once indistinguishable from one that worked.
class PrefsPractisedStepStore implements PractisedStepStore {
  const PrefsPractisedStepStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  /// Named for what it holds rather than for the screen that reads it, so a
  /// later reader of the device's storage can tell what it is.
  static const String key = 'akimath.practised_steps.v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs => _preferences ?? SharedPreferencesAsync();

  @override
  Future<Map<String, int>> read() async {
    try {
      final String? stored = await _prefs.getString(key);
      if (stored == null || stored.isEmpty) {
        return const <String, int>{};
      }
      final Object? decoded = json.decode(stored);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('a practised record is a JSON object');
      }
      return readPractisedSteps(decoded);
    } catch (error) {
      // Deliberately broad, the same as `PrefsAnswerRecordStore`: a key holding
      // the wrong type throws a `TypeError`, which is an `Error` and not an
      // `Exception`, so `on Exception` would let it kill the launch.
      debugPrint('akimath: could not read the practised steps — $error');
      return const <String, int>{};
    }
  }

  @override
  Future<Map<String, int>> record({
    required String family,
    required int step,
  }) async {
    // Read first, so a record corrupted once starts counting again on the next
    // practice run rather than leaving a player with a flat map for ever.
    final Map<String, int> next =
        practisedWith(await read(), family: family, step: step);
    try {
      await _prefs.setString(key, json.encode(next));
    } catch (error) {
      // The step stays in the returned record for this launch. Saying so is the
      // difference between a mystery and a message.
      debugPrint('akimath: could not write the practised steps — $error');
    }
    return next;
  }
}
