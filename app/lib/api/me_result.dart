import 'package:meta/meta.dart';

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
