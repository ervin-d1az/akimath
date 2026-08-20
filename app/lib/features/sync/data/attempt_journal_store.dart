import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../policy/attempt_journal.dart';

/// Where the journal lives between launches.
///
/// **A seam, because the journal has to survive a restart.** Play is offline
/// and sync is not: a player answers on a bus and the batch goes days later,
/// possibly several launches later. An in-memory journal would lose a week of
/// work to one restart, which is the failure the whole feature exists to
/// prevent.
abstract interface class AttemptJournalStore {
  /// What is waiting to be sent. Returns an empty list rather than throwing
  /// when there is nothing to read or what is there cannot be read.
  Future<List<JournalledAttempt>> read();

  /// Replaces the journal with [attempts].
  Future<void> write(List<JournalledAttempt> attempts);
}

/// A journal that forgets when the app closes.
///
/// Not a stub — it is the right implementation of "remember within a session",
/// and it is what a test uses so a widget test never touches a plugin.
class InMemoryAttemptJournalStore implements AttemptJournalStore {
  InMemoryAttemptJournalStore([List<JournalledAttempt> initial = const <JournalledAttempt>[]])
      : _attempts = List<JournalledAttempt>.of(initial);

  List<JournalledAttempt> _attempts;

  @override
  Future<List<JournalledAttempt>> read() async => List<JournalledAttempt>.of(_attempts);

  @override
  Future<void> write(List<JournalledAttempt> attempts) async {
    _attempts = List<JournalledAttempt>.of(attempts);
  }
}

/// The journal, kept on the device.
///
/// **One key, one JSON array.** The journal's own shape is `policy/`'s and this
/// adapter does no formatting of its own beyond the encode.
///
/// It never throws — a pending batch is not worth a launch — but it does **not
/// fail silently**, for the reason `PrefsDayLogStore` records: a store that
/// could not write at all was once indistinguishable from one that worked, and
/// the app showed a zero with nothing anywhere saying why.
///
/// **A row that will not read is dropped and the rest are kept.** The
/// alternative is losing a whole journal to one bad entry, and the entries are
/// independent — the server keys each by its own source.
class PrefsAttemptJournalStore implements AttemptJournalStore {
  const PrefsAttemptJournalStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  /// Named for what it holds rather than for the feature, so a later reader of
  /// the device's storage can tell what it is.
  static const String key = 'akimath.attempt_journal.v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs => _preferences ?? SharedPreferencesAsync();

  @override
  Future<List<JournalledAttempt>> read() async {
    try {
      final String? stored = await _prefs.getString(key);
      if (stored == null || stored.isEmpty) {
        return const <JournalledAttempt>[];
      }
      final Object? decoded = json.decode(stored);
      if (decoded is! List<Object?>) {
        throw const FormatException('a journal is a JSON array');
      }
      final List<JournalledAttempt> read = <JournalledAttempt>[];
      for (final Object? row in decoded) {
        try {
          if (row is Map<String, Object?>) {
            read.add(JournalledAttempt.fromJson(row));
          }
        } on FormatException catch (error) {
          debugPrint('akimath: dropped an unreadable journal row — $error');
        }
      }
      return read;
    } catch (error) {
      // Deliberately broad, the same as `PrefsDayLogStore`: a key holding the
      // wrong type throws a `TypeError`, which is an `Error` and not an
      // `Exception`, so `on Exception` would let it kill the launch.
      debugPrint('akimath: could not read the attempt journal — $error');
      return const <JournalledAttempt>[];
    }
  }

  @override
  Future<void> write(List<JournalledAttempt> attempts) async {
    try {
      await _prefs.setString(
        key,
        json.encode(attempts.map((JournalledAttempt a) => a.toJson()).toList()),
      );
    } catch (error) {
      // The answers stay in memory for this launch and go on the next sync
      // that works. Saying so is the difference between a mystery and a
      // message.
      debugPrint('akimath: could not write the attempt journal — $error');
    }
  }
}
