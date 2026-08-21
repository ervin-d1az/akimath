import '../../../api/me_result.dart';

/// What asking the server for a pack came to.
///
/// **PURE** — a result in, one of three answers out. No socket, no widget, no
/// clock.
///
/// It exists because *"the device is offline"* is a claim, and the only
/// evidence this app ever has for it is a request that went nowhere. Reading
/// that off a `switch` inside the route would put the judgement next to the
/// socket, where the next branch gets added without anyone noticing that a
/// 401 has quietly started meaning *no signal*.
///
/// **This is `accountStateFor`'s shape, deliberately.** That function maps
/// `MeUnreachable` to `AccountState.offline` and every other `MeResult` to
/// something else; these two make the same call about the two results the home
/// can see, so the profile and the home cannot end up disagreeing about what
/// being offline is.
enum PackAsk {
  /// Nothing was asked.
  ///
  /// No session to ask on — unlinked play is entirely offline by design
  /// (ADR 0002), so there is no request and therefore no evidence of anything
  /// — or a pack already in hand, which is the same silence for the same
  /// reason.
  notAsked,

  /// The server answered. With a pack, a refusal, a 404 or something
  /// unreadable: the distinction that matters here is only that it *spoke*.
  answered,

  /// Nothing answered at all. The one outcome that is evidence of no signal.
  nothingAnswered,
}

/// What `POST /packs` came to.
PackAsk issueAsk(IssueResult result) => switch (result) {
  IssueDone() || IssueNoPlayer() || IssueRejected() || IssueFailed() =>
    PackAsk.answered,
  IssueUnreachable() => PackAsk.nothingAnswered,
};

/// What `GET /packs/{packId}` came to.
///
/// **Its own function, because the results are their own sealed type.** One
/// function over both would take a supertype they do not share, and the
/// exhaustiveness that makes a tenth result variant a compile error here is
/// the whole point.
PackAsk fetchAsk(FetchPackResult result) => switch (result) {
  FetchPackDone() || FetchPackGone() || FetchPackRejected() ||
  FetchPackFailed() =>
    PackAsk.answered,
  FetchPackUnreachable() => PackAsk.nothingAnswered,
};
