import '../../../api/me.dart';
import '../../../api/me_result.dart';

/// What the account section is showing, as one closed set.
///
/// **PURE** — a result in, a state out. No widget, no clock, no network.
///
/// It exists because a screen that switches on `MeResult` inline ends up
/// deciding copy in four places, and the fourth is the one nobody writes:
/// `Cargando` is not a `MeResult` at all, it is the absence of one.
enum AccountState {
  /// No account on this device yet. `4.8`'s shape: an invitation, not a lack.
  none,

  /// A request is in flight. `Cargando`.
  loading,

  /// Linked, and the server knows the player.
  linked,

  /// Linked, and the server has no player under the account. Not an error:
  /// it is the ordinary state between an account and a first sync.
  noPlayer,

  /// The session was refused. The account is real; this device's token is not.
  rejected,

  /// The server answered something unusable. `Error de servidor`.
  serverError,

  /// Nothing answered. `Sin conexión` — **not an error's colour.** The
  /// plan is explicit: *"Sin conexión no es un error del usuario: va en
  /// amarillo."*
  offline,

  /// The account already has a player, and it is not this device's.
  ///
  /// **A state of its own, because none of the others is honest about it.** It
  /// is not an error the player made, not a refused session, and not something
  /// a retry fixes: migration 0003 gives an account one player, so signing in
  /// on a second phone means choosing which one the account belongs to. That
  /// choice is a product decision nobody has made, so the app says what is true
  /// and stops.
  ///
  /// This is the conflict where *"otro teléfono"* is the true sentence: the
  /// player the account holds was minted somewhere else.
  otherDevice,

  /// This device's player already belongs to a different account.
  ///
  /// **The mirror image of [otherDevice], and for a while the app told them
  /// the same lie.** Measured on a real device: one simulator, two accounts,
  /// and the id in `shared_preferences` still belonging to the first. There was
  /// no other phone, and the screen said there was.
  ///
  /// Unlike [otherDevice] this one has a way out that costs nothing, which is
  /// why it is worth telling apart: signing back in as the account the id
  /// belongs to makes the server answer `existing` rather than a 409.
  otherAccount,

  /// The account and this device's player do not go together, and which way
  /// round is not known.
  ///
  /// **The state that claims the least, and the one a failed probe lands in.**
  /// A 409 says the two do not match and no more — the difference survives only
  /// in the server's English `message`, which is prose and not a contract — so
  /// the direction is settled by asking `GET /me`. When *that* cannot be
  /// reached, this is what is left, and inventing either of the other two
  /// instead would be the same class of untruth this whole distinction exists
  /// to remove.
  mismatch,
}

/// The one thing the account section offers a player to do about the state it
/// is in.
///
/// **PURE**, and a closed set rather than three booleans on a widget. The view
/// grew `banner`, `detail` and a two-arm label switch over time, and the state
/// that needed a fourth arm is exactly the one that got none of them: a
/// conflict was drawn with no action at all, so a signed-in player was told
/// something untrue with nothing on screen to act on.
enum AccountDoor {
  /// Nothing to press. Either the state is ordinary, or nothing this app can
  /// do would change it — and a button that changes nothing is worse than
  /// none.
  none,

  /// Ask again. Only where a second ask could genuinely answer differently.
  retry,

  /// Open `Error de servidor`, which carries the retry itself.
  detail,

  /// Leave this account. The way out of a conflict between the account signed
  /// in and the progress this phone is holding.
  signOut,
}

/// The label on the sign-out door, wherever it is drawn.
///
/// **One string, because two spellings of one act read as two acts.** Ajustes
/// draws this row and so does the conflict banner; a player who has seen it in
/// one place should recognise it in the other.
const String signOutDoorLabel = 'Cerrar sesión';

/// The state a profile lookup put the section in.
AccountState accountStateFor(MeResult? result) => switch (result) {
  null => AccountState.loading,
  MeFound() => AccountState.linked,
  MeNoPlayer() => AccountState.noPlayer,
  MeRejected() => AccountState.rejected,
  MeFailed() => AccountState.serverError,
  MeUnreachable() => AccountState.offline,
};

/// Whether the state is the player's problem to act on, or ours to apologise
/// for.
///
/// Drives the banner's hue, and it is the one judgement in this file:
/// losing signal is not a mistake anybody made.
bool isOurFault(AccountState state) => switch (state) {
  AccountState.serverError || AccountState.rejected => true,
  AccountState.none ||
  AccountState.loading ||
  AccountState.linked ||
  AccountState.noPlayer ||
  AccountState.offline ||
  AccountState.otherDevice ||
  AccountState.otherAccount ||
  AccountState.mismatch => false,
};

/// What the section offers the player to do about where the account stands.
///
/// **One place, so a state added to [AccountState] cannot quietly get none.**
/// That is not hypothetical: `otherDevice` was drawn as a banner with no action
/// for as long as it existed, because whether a state had a door was three
/// separate expressions on a widget and none of them mentioned it.
AccountDoor accountDoorFor(AccountState state) => switch (state) {
  // `4.10`'s own primary action is the retry, so the banner is a door to it
  // rather than a second copy of it.
  AccountState.serverError => AccountDoor.detail,
  // Signal comes back, and an unrefined conflict refines once the probe lands.
  AccountState.offline || AccountState.mismatch => AccountDoor.retry,
  // The progress on this phone belongs to another account, and going back to
  // it is both non-destructive and the thing that actually resolves the
  // conflict.
  AccountState.otherAccount => AccountDoor.signOut,
  // Nothing this app can do. Moving a player between accounts is undesigned,
  // and signing out would not bring the other phone's progress here.
  AccountState.otherDevice ||
  // A refused session is recovered by the sign-in door on the root, which
  // `_offerToSignIn` already draws — a second one in the banner would be two
  // controls for one act.
  AccountState.rejected ||
  AccountState.none ||
  AccountState.loading ||
  AccountState.linked ||
  AccountState.noPlayer => AccountDoor.none,
};

/// The state a link attempt put the section in.
///
/// **Separate from [accountStateFor], because a link can fail in a way a
/// lookup cannot.** An account that already has another device's player is a
/// 409, and there is no `MeResult` that means it.
///
/// A successful link does not land here: the caller asks `GET /me` next, and
/// what the *server* says the profile is beats what this device just tried to
/// make it. That is the same reading `POST /players/link` answers a `Me` with.
AccountState linkStateFor(LinkResult result) => switch (result) {
  LinkDone() => AccountState.linked,
  // **A 409 alone cannot say which conflict it is**, so this resolves to the
  // state that claims the least and [conflictStateFor] settles it. The server
  // does know — `linkOutcome` in `packages/server/src/link.ts` refuses for two
  // distinct reasons — but `conflictResponse` sends both as `already_linked`
  // and the difference survives only in an English `message`. Branching on that
  // prose would let a copy edit on the server change what this app tells a
  // player, which is a worse defect than the one it would fix.
  LinkConflict() => AccountState.mismatch,
  // A malformed link is this app's bug, not the player's — and it reads as
  // ours, because it is.
  LinkMalformed() => AccountState.serverError,
  LinkRejected() => AccountState.rejected,
  LinkFailed() => AccountState.serverError,
  LinkUnreachable() => AccountState.offline,
};

/// Which way a link conflict runs, settled by what `GET /me` says.
///
/// **The inference is exact rather than a heuristic, and the ordering is why.**
/// `linkOutcome` tests `playerForAccount !== null` *before*
/// `accountForPlayer !== null`, and `GET /me` **is** `playerForAccount`. So a
/// 200 naming a player that is not this device's can only be the first refusal,
/// and a 404 can only be the second — there is no input on which the two
/// overlap, and no field had to be added to the frozen contract to learn it.
///
/// **PURE** — two answers in, a state out. Making the probe is the caller's
/// job.
///
/// The device-local alternative was considered and does not hold: *"an id
/// restored from disk that the server refuses must belong to another account"*
/// is false from the second launch onwards, because `PrefsPlayerIdStore` writes
/// a freshly minted id immediately — so a phone that met the *first* refusal is
/// holding a restored id by its next launch and would be told the wrong story.
AccountState conflictStateFor({
  required MeResult probe,
  required String devicePlayerId,
}) => switch (probe) {
  // The account holds a player and it is not this one, so the progress this
  // account is about lives on whatever device minted that id.
  MeFound(:final Me me) when me.playerId != devicePlayerId =>
    AccountState.otherDevice,
  // A 409 followed by a 200 naming *this* player is a race the
  // one-account-one-player constraint forbids from persisting. The later and
  // more specific answer wins, rather than earning a state nobody could act on.
  MeFound() => AccountState.linked,
  // No player under this account, so the server's own ordering rules the first
  // refusal out: the id this phone holds belongs to somebody else's account.
  MeNoPlayer() => AccountState.otherAccount,
  // The 409 proved the token worked a moment earlier, so a 401 now means it
  // stopped working in between — which is true, and is the one thing here with
  // a door that leads somewhere.
  MeRejected() => AccountState.rejected,
  // The conflict is real and its direction is unknown. Falling through to
  // either sentence would be inventing the answer the probe did not give.
  MeFailed() || MeUnreachable() => AccountState.mismatch,
};
