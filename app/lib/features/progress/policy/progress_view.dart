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

/// Whether the history section is drawn at all.
///
/// **Nothing that can only ever be empty.** The first version of this screen
/// told a player with no history *"los de hoy aparecen aquí"* — and they do
/// not: nothing in the app sends an attempt yet, so the sentence was a promise
/// the product could not keep, on a section that would have stayed empty
/// however much they played. Same reading as the toggles Ajustes does not draw
/// (DR-P2): an affordance that does nothing is worse than an absent one, and so
/// is a heading.
///
/// So the section appears when there is something **true** to say: a list, a
/// wait for one, or a failure to fetch one. It stays away for the two states
/// that are just "there is nothing", which are also the two the player can do
/// nothing about from here — creating an account is Ajustes' job.
bool historyWorthDrawing(HistoryState state) => switch (state) {
  HistoryState.ready ||
  HistoryState.loading ||
  HistoryState.rejected ||
  HistoryState.serverError ||
  HistoryState.offline => true,
  HistoryState.noAccount || HistoryState.empty => false,
};

/// The line the section leads with, for the states that are not a list.
///
/// Null where there is no line: [HistoryState.ready] has the list itself, and
/// the two states [historyWorthDrawing] refuses have no section to put one in.
String? historyMessage(HistoryState state) => switch (state) {
  HistoryState.noAccount => null,
  HistoryState.loading => null,
  HistoryState.ready => null,
  HistoryState.empty => null,
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
