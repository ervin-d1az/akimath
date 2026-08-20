import '../../../api/history.dart';
import '../../../api/me_result.dart';

/// What `Avance` is showing, as one closed set.
///
/// **PURE** — a result in, a state out. No widget, no clock, no socket.
///
/// The screen has two halves and they fail independently. The local figures —
/// days practised, the current run — are always there, because a device that
/// has never synced still knows what it did. The history is the server's, and
/// it has the states a request has, plus the one that is not a request at all:
/// there is no account, so there is nothing to ask.
enum HistoryState {
  /// No account on this device. Not an error — the ordinary state of somebody
  /// who has never linked, and the local figures are still true.
  noAccount,

  /// A request is in flight.
  loading,

  /// The server answered and the player has sessions.
  ready,

  /// The server answered and there are none yet. Distinct from [ready] because
  /// the screen says something different, and distinct from an error because
  /// nothing went wrong.
  empty,

  /// The session was refused. The account is real; this device's token is not.
  rejected,

  /// The server answered something unusable.
  serverError,

  /// Nothing answered.
  offline,
}

/// The state a history lookup put the section in.
///
/// `null` is the wait, the same shape `accountStateFor` uses: the absence of a
/// result is a state a screen has to draw and it is not one the union carries.
HistoryState historyStateFor(HistoryResult? result) => switch (result) {
  null => HistoryState.loading,
  HistoryFound(:final History history) =>
    history.isEmpty ? HistoryState.empty : HistoryState.ready,
  // The account exists and no player is linked to it, which for this screen is
  // the same nothing as an empty history: there is no play to show.
  HistoryNoPlayer() => HistoryState.empty,
  HistoryRejected() => HistoryState.rejected,
  HistoryFailed() => HistoryState.serverError,
  HistoryUnreachable() => HistoryState.offline,
};

/// Whether asking again could answer differently.
///
/// A refused session does not recover by being asked twice; an empty history
/// is an answer, not a failure.
bool canRetryHistory(HistoryState state) => switch (state) {
  HistoryState.offline || HistoryState.serverError => true,
  HistoryState.noAccount ||
  HistoryState.loading ||
  HistoryState.ready ||
  HistoryState.empty ||
  HistoryState.rejected => false,
};

/// Whether the state is ours to apologise for.
///
/// Losing signal is not a mistake anybody made — the same judgement
/// `isOurFault` makes for the account section, and it drives the same hue.
bool isOurProblem(HistoryState state) => switch (state) {
  HistoryState.serverError || HistoryState.rejected => true,
  HistoryState.noAccount ||
  HistoryState.loading ||
  HistoryState.ready ||
  HistoryState.empty ||
  HistoryState.offline => false,
};

/// The line the history section leads with, for the states that are not a list.
///
/// [HistoryState.ready] has none: the list is the message.
String? historyMessage(HistoryState state) => switch (state) {
  HistoryState.noAccount =>
    'Crea una cuenta y tus retos empiezan a guardarse aquí también.',
  HistoryState.loading => null,
  HistoryState.ready => null,
  HistoryState.empty => 'Todavía no hay retos guardados. Los de hoy aparecen aquí.',
  HistoryState.rejected => 'Tu sesión caducó. Vuelve a entrar.',
  HistoryState.serverError => 'No pudimos traer tu historial.',
  HistoryState.offline => 'Sin conexión. Tu avance de este teléfono sigue aquí.',
};

/// The months, abbreviated, in es-MX.
///
/// **Written out rather than fetched from a locale.** `intl` is a dependency
/// and this is twelve words; `CLAUDE.md`'s rule is that nothing goes in without
/// an audit, and a package that pulls locale data to abbreviate a month is not
/// a trade this product needs to make.
const List<String> _months = <String>[
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// `19 ago`, the way a date reads beside a score.
///
/// **Given a local instant, not a UTC one.** The server records when a session
/// happened and says so in UTC; a player in Mexico who practised at nine in the
/// evening should not read tomorrow's date. Converting is the caller's, because
/// the device's zone is not something a pure function may read.
///
/// No year: everything this screen shows is recent, and a year on every row is
/// noise until one of them is old enough to need it.
String entryDate(DateTime local) => '${local.day} ${_months[local.month - 1]}';
