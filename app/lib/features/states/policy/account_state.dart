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
  AccountState.offline => false,
};
