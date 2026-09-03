/// What to do about the pack this device holds, on a launch.
///
/// **PURE** — an account, a stored id and a clock in, one of three answers out.
/// No socket, no storage.
///
/// It exists because the decision has three branches and each of them is a
/// request or the absence of one, which is exactly the sort of thing that grows
/// a fourth branch inside a `Future` chain where nobody can see it.
library;

import '../../states/policy/account_state.dart';

/// Whether the server holds a player this device's packs can be issued to.
///
/// **A session is not a player**, and issuing needs the player: `POST /packs`
/// resolves it from the session and answers 404 when the account holds none.
/// This is the distinction the parameter used to miss — it took *is there a
/// session*, which is true a whole round trip before the answer this decision
/// actually needs.
enum PackAccount {
  /// There is none to issue to.
  ///
  /// Either no session at all — unlinked play is entirely offline (ADR 0002),
  /// the bundled pack is the whole of it, for ever and by design — or a session
  /// whose account the server holds no player of this device's under, which is
  /// the ordinary state between signing in and `POST /players/link` landing.
  noPlayer,

  /// The server holds this device's player, so a pack can be addressed to it.
  linked,
}

/// What the account state a profile lookup or a link produced means for a pack.
///
/// **Exhaustive rather than `state == AccountState.linked`**, so an eleventh
/// [AccountState] is a compile error here instead of quietly meaning *do not
/// issue*. The two are not the same question and the answer is not always the
/// obvious one: a conflict means the account has a player, just not this
/// device's, and the app has already stopped rather than acting on it.
PackAccount packAccountFor(AccountState state) => switch (state) {
      // The link answered, and it answered with a player.
      AccountState.linked => PackAccount.linked,
      // Nothing has been asked yet, or the asking is in flight. Both become
      // [PackAccount.linked] the moment the link lands, and the caller is
      // rebuilt when it does.
      AccountState.none || AccountState.loading => PackAccount.noPlayer,
      // The server was reached and said there is no player, or could not be
      // reached at all. Issuing now would 404 or go nowhere.
      AccountState.noPlayer ||
      AccountState.offline ||
      AccountState.rejected ||
      AccountState.serverError =>
        PackAccount.noPlayer,
      // The account has a player and it is not this device's — or which way
      // round is not known. A pack issued here would be addressed to somebody
      // else's progress, and the app is already telling the player it has
      // stopped; asking for one anyway would contradict the screen.
      AccountState.otherDevice ||
      AccountState.otherAccount ||
      AccountState.mismatch =>
        PackAccount.noPlayer,
    };

/// What the device should do next.
enum PackRefresh {
  /// Nothing: there is no player to issue a pack to, so there is nothing to
  /// ask. See [PackAccount.noPlayer] for the two ways that happens.
  none,

  /// Ask for a new one. Either this device has never been issued a pack, or the
  /// one it holds has lapsed past its window.
  issue,

  /// Fetch the one whose id is stored. The server rebuilds it byte for byte,
  /// so this is the same pack and not a new one.
  fetch,
}

/// The decision.
///
/// [expiresAt] is what the *device* last knew about the stored pack, or null
/// when it knows nothing — a fresh install, or a store that could not be read.
/// A lapsed pack is issued rather than fetched, because the server would refuse
/// it anyway and a round trip to be told so is a round trip.
///
/// **A pack expiring in the next minute counts as lapsed.** The window is
/// measured in weeks; handing a player a pack that dies mid-series to save one
/// request is the wrong trade, and the boundary has to fall somewhere.
PackRefresh packRefresh({
  required PackAccount account,
  required String? storedPackId,
  required DateTime? expiresAt,
  required DateTime now,
}) {
  if (account == PackAccount.noPlayer) {
    return PackRefresh.none;
  }
  if (storedPackId == null || storedPackId.isEmpty) {
    return PackRefresh.issue;
  }
  if (expiresAt != null && !expiresAt.isAfter(now.add(expiryMargin))) {
    return PackRefresh.issue;
  }
  return PackRefresh.fetch;
}

/// How close to its end a pack is treated as already over.
const Duration expiryMargin = Duration(minutes: 1);
