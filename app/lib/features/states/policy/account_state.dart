import '../../../api/me_result.dart';

/// What the account section is showing, as one closed set.
///
/// **PURE** — a result in, a state out. No widget, no clock, no network.
///
/// It exists because a screen that switches on `MeResult` inline ends up
/// deciding copy in four places, and the fourth is the one nobody writes:
/// `4.11 Cargando` is not a `MeResult` at all, it is the absence of one.
enum AccountState {
  /// No account on this device yet. `4.8`'s shape: an invitation, not a lack.
  none,

  /// A request is in flight. `4.11 Cargando`.
  loading,

  /// Linked, and the server knows the player.
  linked,

  /// Linked, and the server has no player under the account. Not an error:
  /// it is the ordinary state between an account and a first sync.
  noPlayer,

  /// The session was refused. The account is real; this device's token is not.
  rejected,

  /// The server answered something unusable. `4.10 Error de servidor`.
  serverError,

  /// Nothing answered. `4.9 Sin conexión` — **not an error's colour.** The
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
  otherDevice,
}

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
  AccountState.otherDevice => false,
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
  LinkConflict() => AccountState.otherDevice,
  // A malformed link is this app's bug, not the player's — and it reads as
  // ours, because it is.
  LinkMalformed() => AccountState.serverError,
  LinkRejected() => AccountState.rejected,
  LinkFailed() => AccountState.serverError,
  LinkUnreachable() => AccountState.offline,
};
