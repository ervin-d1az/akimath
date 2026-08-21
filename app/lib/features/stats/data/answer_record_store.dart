import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../policy/local_stats.dart';

/// Where the answered-item record lives between launches.
///
/// **A seam, because the figures are about more than one sitting.** `78%
/// ACIERTOS` over the five items played since the app opened is not the fact
/// `4.1` is drawing; it has to survive a restart or it is a different number
/// with the same label.
///
/// **The first run does not record, and nothing here enforces that — the caller
/// does.** `0.3 Primer reto` is a teaching item: it records no day and shows no
/// streak, and it should not move accuracy either, because the figure is about
/// how the player is doing and the tutorial is about how the app works. The
/// mechanism is the one `DayLogStore` already uses — the round is built without
/// a store, so there is nothing to record into. Wiring this in means passing a
/// recorder to the practice round and **not** to `FirstItemScreen`.
abstract interface class AnswerRecordStore {
  /// The window as it stands, oldest first. Returns an empty record rather than
  /// throwing when there is nothing to read or what is there cannot be read.
  Future<List<AnsweredItem>> read();

  /// Remembers [answer] and returns the record it wrote.
  ///
  /// It returns rather than voids so a caller that has just recorded can draw
  /// the new figure without a second read — that second await is where a stale
  /// screen comes from.
  Future<List<AnsweredItem>> record(AnsweredItem answer);
}

/// A record that forgets when the app closes.
///
/// Not a stub — it is the right implementation of "remember within a session",
/// and it is what a widget test uses so a pumped screen never touches a plugin.
class InMemoryAnswerRecordStore implements AnswerRecordStore {
  InMemoryAnswerRecordStore([
    List<AnsweredItem> initial = const <AnsweredItem>[],
  ]) : _record = List<AnsweredItem>.of(initial);

  List<AnsweredItem> _record;

  @override
  Future<List<AnsweredItem>> read() async => List<AnsweredItem>.of(_record);

  @override
  Future<List<AnsweredItem>> record(AnsweredItem answer) async {
    _record = recordedWith(_record, answer);
    return List<AnsweredItem>.of(_record);
  }
}

/// The record, kept on the device.
///
/// **One key, one JSON array**, on the `shared_preferences` the day log and the
/// attempt journal already use — no new dependency, and that audit is recorded
/// in `dependency_allowlist_test.dart`.
///
/// **It holds no arithmetic.** The window is `recordedWith`'s and the figures
/// are `LocalStats`'s; this translates and nothing else (PURE-2).
///
/// It never throws — a profile figure is not worth a launch — but it does not
/// fail silently either, for the reason `PrefsDayLogStore` records: a store
/// that could not write at all was once indistinguishable from one that worked.
class PrefsAnswerRecordStore implements AnswerRecordStore {
  const PrefsAnswerRecordStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  /// Named for what it holds rather than for the feature, so a later reader of
  /// the device's storage can tell what it is.
  static const String key = 'akimath.answered_items.v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs => _preferences ?? SharedPreferencesAsync();

  @override
  Future<List<AnsweredItem>> read() async {
    try {
      final String? stored = await _prefs.getString(key);
      if (stored == null || stored.isEmpty) {
        return const <AnsweredItem>[];
      }
      final Object? decoded = json.decode(stored);
      if (decoded is! List<Object?>) {
        throw const FormatException('a record is a JSON array');
      }
      return _rowsOf(decoded);
    } catch (error) {
      // Deliberately broad, the same as `PrefsAttemptJournalStore`: a key
      // holding the wrong type throws a `TypeError`, which is an `Error` and
      // not an `Exception`, so `on Exception` would let it kill the launch.
      debugPrint('akimath: could not read the answer record — $error');
      return const <AnsweredItem>[];
    }
  }

  @override
  Future<List<AnsweredItem>> record(AnsweredItem answer) async {
    // Read first, so a record corrupted once starts counting again on the next
    // answer rather than leaving a player with no figures for ever.
    final List<AnsweredItem> next = recordedWith(await read(), answer);
    try {
      await _prefs.setString(
        key,
        json.encode(next.map((AnsweredItem a) => a.toJson()).toList()),
      );
    } catch (error) {
      // The answers stay in memory for this launch. Saying so is the difference
      // between a mystery and a message.
      debugPrint('akimath: could not write the answer record — $error');
    }
    return next;
  }

  /// **A row that will not read is dropped and the rest are kept.** The rows are
  /// independent and the figures are an average over what is left, so losing a
  /// whole record to one bad row is the worse of the two outcomes.
  List<AnsweredItem> _rowsOf(List<Object?> decoded) {
    final List<AnsweredItem> read = <AnsweredItem>[];
    for (final Object? row in decoded) {
      try {
        if (row is Map<String, Object?>) {
          read.add(AnsweredItem.fromJson(row));
        }
      } on FormatException catch (error) {
        debugPrint('akimath: dropped an unreadable answer row — $error');
      }
    }
    return read;
  }
}
