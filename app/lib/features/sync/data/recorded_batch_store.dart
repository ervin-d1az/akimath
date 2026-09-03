import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How many batches of attempts this device has had **recorded** by the server.
///
/// **The one fact a second root needs, and the smallest one that answers the
/// question.** `GET /me/history` is a read of what the server holds, and what
/// the server holds changes when a batch is recorded and at no other moment —
/// so a tally of recordings is exactly *is there something new to read*,
/// without a clock, without a timestamp to reconcile across two machines, and
/// without any part of what was answered leaving the sync feature.
///
/// **Not the journal's length.** The journal empties for a 400 and a 404 too
/// (`journalAfter`), where the batch reached the server and nothing was
/// written — so an emptied journal cannot tell *recorded* from *dropped*, and a
/// reader keyed on it would re-ask for rows that cannot exist.
/// [attemptsWereRecorded] is where that distinction lives, and this store is
/// only its tally.
///
/// **Persisted, because the two ends are two roots.** `AttemptSync` belongs to
/// Inicio and to Mapa; Perfil is a sibling under an `IndexedStack` and holds
/// neither. `shared_preferences` is the seam they already share — and it makes
/// a batch that lands during a launch legible to a profile opened later in the
/// same launch, which is the case measured on 2026-09-02.
///
/// The same two-sided seam every store here has: an interface a test hands
/// memory to, and the implementation the app runs on.
abstract interface class RecordedBatchStore {
  /// The tally, or 0 for a device that has never synced. Never throws: the
  /// worst outcome of answering 0 is one history request nobody needed, and the
  /// worst outcome of a throw is a launch that fails.
  Future<int> read();

  /// One more batch is on the server.
  Future<void> countOne();
}

/// A tally that forgets when the app closes — correct for a test, and for
/// anything that only cares about this launch.
class InMemoryRecordedBatchStore implements RecordedBatchStore {
  InMemoryRecordedBatchStore([this._recorded = 0]);

  int _recorded;

  @override
  Future<int> read() async => _recorded;

  @override
  Future<void> countOne() async => _recorded++;
}

/// The device's own tally.
class PrefsRecordedBatchStore implements RecordedBatchStore {
  const PrefsRecordedBatchStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  /// Named for what it holds rather than for the feature, so a later reader of
  /// the device's storage can tell what it is.
  static const String key = 'akimath.recorded_batches.v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs => _preferences ?? SharedPreferencesAsync();

  @override
  Future<int> read() async {
    try {
      return await _prefs.getInt(key) ?? 0;
    } catch (error) {
      // **Deliberately broad**, the same reading `PrefsIssuedPackStore`
      // records: a key holding the wrong type throws a `TypeError`, which is an
      // `Error` and not an `Exception`, so `on Exception` misses it and a
      // launch dies on a corrupt preference.
      debugPrint('recorded batches: could not read ($error)');
      return 0;
    }
  }

  @override
  Future<void> countOne() async {
    try {
      await _prefs.setInt(key, await read() + 1);
    } catch (error) {
      // The count stalls, so a reader keyed on it asks one time fewer than it
      // should. Saying so is the difference between a mystery and a message —
      // the same reason `PrefsAttemptJournalStore` does not fail silently.
      debugPrint('recorded batches: could not write ($error)');
    }
  }
}
