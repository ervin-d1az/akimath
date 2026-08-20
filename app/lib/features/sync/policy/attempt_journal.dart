import 'package:meta/meta.dart';

import '../../../api/me_result.dart';
import '../../../api/sync.dart';

/// What the device remembers answering until the server has it.
///
/// **PURE** — a list in, a list out. Reading and writing it is
/// `data/prefs_attempt_journal.dart`.
///
/// **It exists because play is offline and sync is not.** A player answers on a
/// bus; the batch goes when there is signal, which may be days and several
/// launches later. An in-memory list would lose a week of work to one restart,
/// which is the failure this whole feature is supposed to prevent.
///
/// **Nothing here decides whether an answer was right.** The journal carries
/// what was typed and when, and the verdict comes back from the server — the
/// same construction the wire has, kept on this side so a future screen cannot
/// start reading a local verdict and quietly diverge from the recorded one.
@immutable
class JournalledAttempt {
  const JournalledAttempt({
    required this.packId,
    required this.index,
    required this.sessionId,
    required this.answer,
    required this.at,
    required this.elapsed,
  });

  factory JournalledAttempt.fromJson(Map<String, Object?> json) {
    final Object? packId = json['packId'];
    final Object? index = json['index'];
    final Object? sessionId = json['sessionId'];
    final Object? answer = json['answer'];
    final Object? at = json['at'];
    final Object? elapsedMs = json['elapsedMs'];
    if (packId is! String ||
        index is! int ||
        sessionId is! String ||
        answer is! String ||
        at is! String ||
        elapsedMs is! int) {
      throw FormatException('not a journalled attempt', json.toString());
    }
    return JournalledAttempt(
      packId: packId,
      index: index,
      sessionId: sessionId,
      answer: answer,
      at: DateTime.parse(at).toUtc(),
      elapsed: Duration(milliseconds: elapsedMs),
    );
  }

  final String packId;

  /// Position in `pack.items`. With `packId`, this *is* the item's identity.
  final int index;

  final String sessionId;
  final String answer;
  final DateTime at;
  final Duration elapsed;

  /// What the batch sends. The journal's own shape and the wire's are separate
  /// on purpose: one is storage this app owns and the other is a frozen
  /// contract, and letting a stored row be a wire row makes a schema change a
  /// migration of everybody's phone.
  AttemptSubmission toSubmission() => AttemptSubmission(
        packRef: PackRef(packId: packId, index: index),
        sessionId: sessionId,
        answer: answer,
        at: at,
        elapsed: elapsed,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'packId': packId,
    'index': index,
    'sessionId': sessionId,
    'answer': answer,
    'at': at.toUtc().toIso8601String(),
    'elapsedMs': elapsed.inMilliseconds,
  };

  /// What makes two rows the same answer.
  ///
  /// The server keys an attempt by its source alone — one item is answered
  /// once, and migration 0004 says so with a unique index. Keeping a second row
  /// for the same item would send a batch the server silently halves.
  String get key => '$packId#$index';

  @override
  bool operator ==(Object other) =>
      other is JournalledAttempt &&
      other.packId == packId &&
      other.index == index &&
      other.sessionId == sessionId &&
      other.answer == answer &&
      other.at == at &&
      other.elapsed == elapsed;

  @override
  int get hashCode => Object.hash(packId, index, sessionId, answer, at, elapsed);

  @override
  String toString() => 'JournalledAttempt($key, "$answer")';
}

/// How many answers the journal keeps.
///
/// **The server's batch limit, which is the real constraint.** It refuses more
/// than two hundred in one request, so a journal that grew past that could
/// never be flushed — every sync would 400 and the backlog would grow for ever.
/// At the ceiling the *oldest* go, because a recent answer is the one a player
/// is waiting to see counted.
const int journalLimit = 200;

/// The journal with one more answer in it.
///
/// **Same item, latest answer wins.** A player who replays an item before
/// syncing has answered it twice and the server will keep one; keeping the
/// later of the two is the one that matches what they last did.
List<JournalledAttempt> journalWith(
  List<JournalledAttempt> journal,
  JournalledAttempt attempt,
) {
  final List<JournalledAttempt> kept = journal
      .where((JournalledAttempt held) => held.key != attempt.key)
      .toList()
    ..add(attempt);

  return kept.length <= journalLimit
      ? kept
      : kept.sublist(kept.length - journalLimit);
}

/// What is left in the journal after a sync answered.
///
/// **The whole decision, in one place, because each case wants something
/// different.**
///
/// · A batch that landed is gone — including every verdict that came back
///   `false`, because "wrong" is a recorded answer and not a failed send.
/// · A batch the server could not read is **dropped**. Resending a malformed
///   one resends it for ever, and the answers in it are already unrecoverable.
/// · A batch naming something the player does not have is dropped for the same
///   reason: the pack is gone or was never theirs, and nothing will make it
///   land.
/// · A refused session is **kept**. The token is what is wrong, not the work.
/// · Unreachable is kept, and this is the case the journal exists for.
/// · Anything unreadable is kept, because a server that answered something new
///   is a server that might answer properly next time.
List<JournalledAttempt> journalAfter(
  List<JournalledAttempt> sent,
  List<JournalledAttempt> journal,
  SyncResult result,
) {
  final bool landed = switch (result) {
    SyncDone() => true,
    SyncMalformed() => true,
    SyncNoSuchItem() => true,
    SyncRejected() => false,
    SyncFailed() => false,
    SyncUnreachable() => false,
  };
  if (!landed) {
    return journal;
  }

  final Set<String> gone = sent.map((JournalledAttempt a) => a.key).toSet();
  // Only what was *sent* is removed. A player who answered another item while
  // the request was in flight has an entry the server has never seen.
  return journal
      .where((JournalledAttempt held) => !gone.contains(held.key))
      .toList(growable: false);
}
