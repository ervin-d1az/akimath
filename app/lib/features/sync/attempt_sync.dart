import 'dart:math';

import '../../api/api_client.dart';
import '../../api/endpoints.dart';
import '../../content/model/issued_pack.dart';
import '../account/policy/player_id.dart';
import 'data/attempt_journal_store.dart';
import 'policy/attempt_journal.dart';

/// What the device remembers until the server has it.
///
/// **ADAPTER.** Every decision it makes is already written down and pure —
/// `journalWith`, `journalAfter`, `readIssuedItemId` — and this owns the store
/// and the socket that those must not.
///
/// It is the writer the journal has never had. `attempt_journal.dart` and its
/// store landed with the client half of the offline loop and nothing called
/// either, so the server's seven endpoints were unreachable from actual play
/// and `HISTORIAL` could never fill.
///
/// **Two halves that must not be one.** [record] runs when a player answers and
/// never touches the network — play is offline and a submit that waited on a
/// socket would be a pause mid-round. [flush] runs when there is a session and
/// a reason to believe the network is there. A batch goes days and several
/// launches after the answers in it, which is what the journal is for.
class AttemptSync {
  AttemptSync({
    AttemptJournalStore? store,
    Future<SyncResult> Function({
      required String accessToken,
      required List<AttemptSubmission> attempts,
    })? submit,
    Random? random,
  })  : _store = store ?? const PrefsAttemptJournalStore(),
        _submit = submit,
        _random = random ?? Random.secure();

  final AttemptJournalStore _store;
  final Future<SyncResult> Function({
    required String accessToken,
    required List<AttemptSubmission> attempts,
  })? _submit;
  final Random _random;

  /// A fresh session id for one sitting.
  ///
  /// **Version 4 by construction**, the same reason `playerIdFrom` is: the
  /// frozen schema pins a version and a variant nibble, and sixteen random
  /// bytes fail that about one time in eight.
  ///
  /// One per series rather than one per answer: `GET /me/history` groups by it,
  /// and a history of one-item sessions is a history nobody can read.
  String newSessionId() =>
      playerIdFrom(<int>[for (int i = 0; i < 16; i++) _random.nextInt(256)]);

  /// Remembers an answered item, if it is one the server could grade.
  ///
  /// **An authored item is dropped on purpose and without complaint.** The
  /// bundled pack's items have no `(packId, index)` — nothing on the server
  /// addresses them — so journalling one would be filing a batch that can only
  /// ever come back a 404. `readIssuedItemId` returning null is the whole test.
  ///
  /// No verdict travels: the frozen schema has nowhere to put one, and the
  /// server regrades from the same inputs anyway.
  Future<void> record({
    required String itemId,
    required String sessionId,
    required String answer,
    required DateTime at,
    required Duration elapsed,
  }) async {
    final ({String packId, int index})? address = readIssuedItemId(itemId);
    if (address == null) {
      return;
    }
    final List<JournalledAttempt> journal = await _store.read();
    await _store.write(
      journalWith(
        journal,
        JournalledAttempt(
          packId: address.packId,
          index: address.index,
          sessionId: sessionId,
          answer: answer,
          at: at.toUtc(),
          elapsed: elapsed.isNegative ? Duration.zero : elapsed,
        ),
      ),
    );
  }

  /// Sends what is waiting, and keeps what the answer says to keep.
  ///
  /// Returns the result, or null when there was nothing to send — which is the
  /// ordinary case and not a failure.
  ///
  /// **What survives is `journalAfter`'s decision and not this function's.**
  /// A batch that landed is gone, one the server could not read is dropped
  /// because resending a malformed batch resends it for ever, and a refused
  /// session or no answer at all is kept.
  Future<SyncResult?> flush(String accessToken) async {
    final List<JournalledAttempt> journal = await _store.read();
    if (journal.isEmpty) {
      return null;
    }

    // The whole journal, because it is already capped at what one batch can
    // carry — the server refuses more than two hundred, so a longer journal
    // could never be flushed.
    final List<JournalledAttempt> sending = List<JournalledAttempt>.of(journal);
    final SyncResult result = await (_submit ?? _overASocket)(
      accessToken: accessToken,
      attempts: <AttemptSubmission>[
        for (final JournalledAttempt held in sending)
          AttemptSubmission.forPackItem(
            ref: PackRef(packId: held.packId, index: held.index),
            sessionId: held.sessionId,
            answer: held.answer,
            at: held.at,
            elapsed: held.elapsed,
          ),
      ],
    );

    // Re-read rather than reuse `journal`: a player may have answered another
    // item while the request was in flight, and that entry the server has never
    // seen.
    final List<JournalledAttempt> now = await _store.read();
    await _store.write(journalAfter(sending, now, result));
    return result;
  }

  Future<SyncResult> _overASocket({
    required String accessToken,
    required List<AttemptSubmission> attempts,
  }) async {
    final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
    try {
      return await api.submitAttempts(
        accessToken: accessToken,
        attempts: attempts,
      );
    } finally {
      api.close();
    }
  }
}
