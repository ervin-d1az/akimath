import 'package:meta/meta.dart';

import 'history.dart';
import 'sync.dart';
import 'me.dart';

/// What a profile lookup came back as — the shape of the answer, not the
/// fetching of it.
///
/// **Separate from `api_client.dart` because this is data.** That file imports
/// `dart:io` and `dart:convert` to hold a socket; this one imports neither, so
/// a pure policy may switch on the result without reaching a socket through
/// it. `features/states/policy/account_state.dart` is the caller that made the
/// split necessary — the pure-boundary gate caught it reaching `dart:convert`
/// three hops away.
/// What `GET /me` came back as.
///
/// **A sealed union, so a `switch` over it is exhaustive.** Every status the
/// contract declares for the operation has a case, and everything else has one
/// too — a client that forgot a branch is a compile error rather than a screen
/// that renders nothing.
@immutable
sealed class MeResult {
  const MeResult();
}

/// 200 — the player behind the session.
@immutable
final class MeFound extends MeResult {
  const MeFound(this.me);
  final Me me;
}

/// 404 — the session is good and no player is linked to it yet.
///
/// Not an error. It is the ordinary state of an adult who has made an account
/// and not yet linked a device, and the screen for it is an invitation rather
/// than an apology.
@immutable
final class MeNoPlayer extends MeResult {
  const MeNoPlayer();
}

/// 401 — no session, or one the server would not accept.
@immutable
final class MeRejected extends MeResult {
  const MeRejected({required this.tag, required this.message});

  /// The frozen `Error.error` tag: `unauthenticated` or `invalid_session`.
  final String tag;
  final String message;
}

/// An answer arrived and was not one this client knows how to read.
@immutable
final class MeFailed extends MeResult {
  const MeFailed({required this.status, required this.reason});
  final int status;
  final String reason;
}

/// No answer arrived at all — no route to the host, a refused socket, a timeout.
@immutable
final class MeUnreachable extends MeResult {
  const MeUnreachable(this.reason);
  final String reason;
}

/// What `POST /players/link` came back as.
///
/// Separate from [MeResult] even though both can carry a [Me]: the answers
/// differ where it matters. A link can be refused because the account already
/// has a player, and a lookup cannot; a lookup can find nothing, and a link
/// that found nothing has just created it.
@immutable
sealed class LinkResult {
  const LinkResult();
}

/// 200 — linked, or already linked to this same player.
@immutable
final class LinkDone extends LinkResult {
  const LinkDone(this.me);
  final Me me;
}

/// 409 — this account has another player, or this player has another account.
@immutable
final class LinkConflict extends LinkResult {
  const LinkConflict(this.message);
  final String message;
}

/// 400 — the request was wrong before it reached the database.
@immutable
final class LinkMalformed extends LinkResult {
  const LinkMalformed(this.message);
  final String message;
}

/// 401 — no session, or one the server would not accept.
@immutable
final class LinkRejected extends LinkResult {
  const LinkRejected({required this.tag, required this.message});
  final String tag;
  final String message;
}

/// An answer arrived and was not one this client can read.
@immutable
final class LinkFailed extends LinkResult {
  const LinkFailed({required this.status, required this.reason});
  final int status;
  final String reason;
}

/// No answer arrived at all.
@immutable
final class LinkUnreachable extends LinkResult {
  const LinkUnreachable(this.reason);
  final String reason;
}

/// What `DELETE /me` came back as.
///
/// **A 204 carries no body**, so unlike the other two unions the success case
/// holds nothing. That is the whole reason it is separate: a client that reads
/// this one the way it reads `GET /me` turns a successful erasure into a
/// `FormatException`, and the player is told it failed while the row is
/// already gone — the one error here that cannot be recovered by retrying.
@immutable
sealed class EraseResult {
  const EraseResult();
}

/// 204 — the player and everything referencing them are gone.
@immutable
final class EraseDone extends EraseResult {
  const EraseDone();
}

/// 404 — the session is good and there was no player under it.
///
/// **Not a failure.** The player asked for there to be nothing left, and there
/// is nothing left. It is a separate case from [EraseDone] because the two are
/// different facts to a developer reading a log, and the same outcome to a
/// player reading a screen — `features/preferences/policy/erasure.dart` is
/// where they are collapsed, deliberately and in one place.
@immutable
final class EraseNothingThere extends EraseResult {
  const EraseNothingThere();
}

/// 401 — no session, or one the server would not accept.
@immutable
final class EraseRejected extends EraseResult {
  const EraseRejected({required this.tag, required this.message});
  final String tag;
  final String message;
}

/// An answer arrived and was not one this client can read.
@immutable
final class EraseFailed extends EraseResult {
  const EraseFailed({required this.status, required this.reason});
  final int status;
  final String reason;
}

/// No answer arrived at all.
@immutable
final class EraseUnreachable extends EraseResult {
  const EraseUnreachable(this.reason);
  final String reason;
}

/// What `GET /me/history` came back as.
///
/// Separate from the other three because its 200 carries something none of them
/// do — a list that is legitimately empty. A player who has linked and not yet
/// synced has *no* history and that is not an error, not a 404, and not a
/// state a screen should apologise for.
@immutable
sealed class HistoryResult {
  const HistoryResult();
}

/// 200 — the sessions, newest first. Possibly none of them.
@immutable
final class HistoryFound extends HistoryResult {
  const HistoryFound(this.history);
  final History history;
}

/// 404 — the session is good and no player is linked to it.
@immutable
final class HistoryNoPlayer extends HistoryResult {
  const HistoryNoPlayer();
}

/// 401 — no session, or one the server would not accept.
@immutable
final class HistoryRejected extends HistoryResult {
  const HistoryRejected({required this.tag, required this.message});
  final String tag;
  final String message;
}

/// An answer arrived and was not one this client can read.
@immutable
final class HistoryFailed extends HistoryResult {
  const HistoryFailed({required this.status, required this.reason});
  final int status;
  final String reason;
}

/// No answer arrived at all.
@immutable
final class HistoryUnreachable extends HistoryResult {
  const HistoryUnreachable(this.reason);
  final String reason;
}

/// What `POST /packs` came back as.
@immutable
sealed class IssueResult {
  const IssueResult();
}

/// 200 — a pack, and the id every attempt against it will name.
@immutable
final class IssueDone extends IssueResult {
  const IssueDone(this.issued);
  final IssuedPack issued;
}

/// 404 — the session is good and no player is linked to it.
@immutable
final class IssueNoPlayer extends IssueResult {
  const IssueNoPlayer();
}

/// 401 — no session, or one the server would not accept.
@immutable
final class IssueRejected extends IssueResult {
  const IssueRejected({required this.tag, required this.message});
  final String tag;
  final String message;
}

/// An answer arrived and was not one this client can read.
@immutable
final class IssueFailed extends IssueResult {
  const IssueFailed({required this.status, required this.reason});
  final int status;
  final String reason;
}

/// No answer arrived at all.
@immutable
final class IssueUnreachable extends IssueResult {
  const IssueUnreachable(this.reason);
  final String reason;
}

/// What `POST /attempts` came back as.
///
/// **A refusal is not the same as a wrong answer.** Every verdict in [SyncDone]
/// may be `ok: false` and the sync still succeeded; the cases below are about
/// whether the batch was *recorded*, which is the only thing a client has to
/// decide anything about.
@immutable
sealed class SyncResult {
  const SyncResult();
}

/// 200 — one verdict per attempt, in the order submitted.
@immutable
final class SyncDone extends SyncResult {
  const SyncDone(this.verdicts);
  final List<AttemptVerdict> verdicts;
}

/// 400 — the batch was wrong before it reached the database.
///
/// **Not retryable, and that matters.** A client that resends a malformed batch
/// resends it for ever; this is the one failure a device has to drop rather
/// than keep.
@immutable
final class SyncMalformed extends SyncResult {
  const SyncMalformed(this.message);
  final String message;
}

/// 404 — an attempt names something this player does not have, or the account
/// has no player. Nothing in the batch was recorded.
@immutable
final class SyncNoSuchItem extends SyncResult {
  const SyncNoSuchItem({required this.tag, required this.message});
  final String tag;
  final String message;
}

/// 401 — no session, or one the server would not accept.
@immutable
final class SyncRejected extends SyncResult {
  const SyncRejected({required this.tag, required this.message});
  final String tag;
  final String message;
}

/// An answer arrived and was not one this client can read.
@immutable
final class SyncFailed extends SyncResult {
  const SyncFailed({required this.status, required this.reason});
  final int status;
  final String reason;
}

/// No answer arrived at all. **Keep the batch**: this is the case a retry is
/// for, and the server drops a duplicate by itself (migration 0004).
@immutable
final class SyncUnreachable extends SyncResult {
  const SyncUnreachable(this.reason);
  final String reason;
}
