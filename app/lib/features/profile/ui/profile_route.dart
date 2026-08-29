import 'package:flutter/material.dart';

import 'dart:async';

import '../../../api/api_client.dart';
import '../../../api/me.dart';
import '../../../api/auth_client.dart';
import '../../../api/endpoints.dart';
import '../../auth/ui/auth_flow.dart';
import '../../states/policy/account_state.dart';
import '../../home/data/day_log_store.dart';
import '../../home/data/prefs_day_log_store.dart';
import '../../home/data/series_cursor_store.dart';
import '../../home/policy/day_log.dart';
import '../../round/policy/streak_policy.dart';
import '../../stats/data/answer_record_store.dart';
import '../../stats/policy/local_stats.dart';
import '../policy/history_view.dart';
import '../policy/profile_readout.dart';
import '../../account/data/player_id_store.dart';
import '../../account/policy/session.dart';
import '../../shell/policy/visible_tabs.dart';
import '../../shell/ui/app_shell.dart';
import '../../preferences/policy/erasure.dart';
import '../../preferences/ui/account_screen.dart';
import '../../preferences/ui/change_password_screen.dart';
import '../../preferences/ui/erase_account_route.dart';
import '../../preferences/ui/legend_screen.dart';
import '../../preferences/ui/settings_list_screen.dart';
import 'profile_screen.dart';

/// The profile root, and the stack it pushes.
///
/// **Renamed from `ProfileRoute` and moved, rather than rewritten.**
/// Declared rule 1 names the bar's homes as *inicio, mapa, progreso y perfil*;
/// the third root was Ajustes, which that rule does not name. Everything about
/// the account — linking on a session appearing, the sign-in flow, the erasure
/// — is unchanged and only re-parented; a review that finds logic moving inside
/// one of them has found something worth asking about (D6).
///
/// It owns the pushes because it owns the session and the token: `Cuenta`'s
/// erasure needs both, and a screen that took an `ApiClient` could not be
/// driven by a `testWidgets` — a real socket inside a fake-async zone hangs on
/// `!timersPending`, which is why every request here travels as a closure.
class ProfileRoute extends StatefulWidget {
  const ProfileRoute({
    super.key,
    this.session,
    this.onSessionChanged,
    this.now = DateTime.now,
    this.authBaseUrl = Endpoints.authBaseUrl,
    this.playerIds,
    this.link,
    this.dayLog,
    this.answerRecord,
    this.seriesCursor = const SeriesCursorStore(),
    this.fetchHistory,
    this.auth,
    this.whoAmI,
    this.visibility = RootVisibility.showing,
  });

  /// Whether this root is the one on screen.
  ///
  /// **The moment it comes to the front is the only moment it can refresh.**
  /// `RootScaffold` keeps every root alive in an `IndexedStack`, so `initState`
  /// runs once per launch and there is no second one to hook — a figure read
  /// only there is a figure from launch time. Measured on a device: the verdict
  /// screen said `RACHA 1`, the home said `RACHA 1 DÍA`, and Perfil said `0`.
  ///
  /// Defaults to [RootVisibility.showing], because every caller that is not the
  /// shell — a test, the screen registry — is looking at it.
  final RootVisibility visibility;

  /// Neon Auth, when a test stands in for it.
  ///
  /// Null in the app, where this route opens an [AuthClient] of its own and
  /// closes it again — it closes only what it opened, so an injected provider
  /// outlives the flow it was handed to.
  final AuthApi? auth;

  /// Asks the AkiMath server who a token belongs to. A closure, for the reason
  /// every other request here is one.
  final Future<MeResult> Function(String accessToken)? whoAmI;

  /// Where this device's own player id lives. Injected so a widget test never
  /// reaches a plugin.
  final PlayerIdStore? playerIds;

  /// Attaches this device's player to the account. A closure rather than an
  /// `ApiClient`, the same shape `EraseAccountRoute` takes and for the same
  /// reason: `testWidgets` runs in a fake-async zone and a real socket inside
  /// one hangs on `!timersPending`.
  final Future<LinkResult> Function({
    required String accessToken,
    required String playerId,
    required AgeBand ageBand,
  })? link;

  /// The account this device is signed in to, owned by the shell.
  ///
  /// **Lifted out of this route when `Avance` arrived.** Two roots have to
  /// agree about whether there is an account — one signs in and the other shows
  /// what the account holds — and the only place that can hold that is their
  /// common ancestor.
  final LinkedSession? session;

  /// Reports a sign-in, or a sign-out when the account is erased.
  final ValueChanged<LinkedSession?>? onSessionChanged;

  /// Where Neon Auth is, defaulting to the build's own `--dart-define`.
  ///
  /// **A parameter and not a direct read of the constant**, because a
  /// compile-time constant is one no test can vary — and "the door appears when
  /// the build was configured" is exactly the claim worth checking. It was
  /// asserted here once and was false: the first simulator build reused a
  /// cached kernel, the defines never landed, and the row silently did not
  /// render.
  final String authBaseUrl;

  /// Injected, so the streak can be tested by handing it a date.
  final DateTime Function() now;

  /// Where the days practised are kept. Injected so a widget test never
  /// reaches a plugin.
  final DayLogStore? dayLog;

  /// What this device answered, and the source of `ACIERTOS` and `PROMEDIO`.
  ///
  /// **The same store the round writes to**, defaulted rather than required for
  /// the reason [dayLog] is: the app has one and a widget test hands over an
  /// in-memory one. Two figures the profile used to invent come out of it, and
  /// both are **absent over an empty record** rather than zero — that decision
  /// is `LocalStats`'s and this route only passes it on.
  final AnswerRecordStore? answerRecord;

  /// How many items this device has been served, across every session.
  ///
  /// **The home's store, read here.** It is a persisted running total advanced
  /// when a series finishes, which is exactly what `RETOS` counts; a second
  /// tally kept by the profile would be a second answer to one question.
  final SeriesCursorStore seriesCursor;

  /// Asks the server what this account has played. **A closure**, the same
  /// shape every other request on this route takes and for the same reason: a
  /// `testWidgets` runs in a fake-async zone and a real socket inside one hangs
  /// on `!timersPending`.
  final Future<HistoryResult> Function(String accessToken)? fetchHistory;

  @override
  State<ProfileRoute> createState() => _ProfileRouteState();
}

class _ProfileRouteState extends State<ProfileRoute> {
  late final DayLogStore _dayLog = widget.dayLog ?? const PrefsDayLogStore();
  late final AnswerRecordStore _answerRecord =
      widget.answerRecord ?? const PrefsAnswerRecordStore();
  DayLog _log = DayLog.empty;
  int _challenges = 0;

  /// What the record adds up to. Empty until it is read, which is the same
  /// figure a player who has answered nothing gets — so nothing waits on it.
  LocalStats _stats = LocalStats.of(const <AnsweredItem>[]);
  HistoryResult? _history;

  @override
  void initState() {
    super.initState();
    _linkIfNeeded(null);
    _readWhatTheDeviceKnows();
    unawaited(_askForHistory());
  }

  /// Every figure that comes from this device's own storage.
  ///
  /// **One list, called from two places**, so a reading added here is refreshed
  /// by [_refreshOnComingToTheFront] without anybody remembering to add it
  /// there too. That is the whole reason this is a method rather than two lines
  /// in `initState`.
  void _readWhatTheDeviceKnows() {
    unawaited(_readDayLog());
    unawaited(_readChallenges());
    unawaited(_readAnswerRecord());
  }

  /// Re-reads storage the moment this root becomes the one on screen.
  ///
  /// **A rebuild is not a visit.** The shell rebuilds every root on every tab
  /// switch, so refreshing on any rebuild would read storage for a screen
  /// nobody is looking at — and would hide the case this exists for. The
  /// transition is what matters: behind, then showing.
  void _refreshOnComingToTheFront(RootVisibility before) {
    if (widget.visibility == RootVisibility.showing &&
        before == RootVisibility.behind) {
      _readWhatTheDeviceKnows();
    }
  }

  @override
  void didUpdateWidget(ProfileRoute old) {
    super.didUpdateWidget(old);
    _linkIfNeeded(old.session);
    _refreshOnComingToTheFront(old.visibility);
    // The session may arrive after this screen is built — `IndexedStack` keeps
    // the roots alive, so signing in elsewhere does not rebuild this one.
    if (widget.session?.accessToken != old.session?.accessToken) {
      setState(() => _history = null);
      unawaited(_askForHistory());
    }
  }

  /// **Never waits on the network.** The figures come from storage and are
  /// always available; a route that fetched both together would hide what the
  /// device already knows behind a request that may never answer.
  Future<void> _readDayLog() async {
    final DayLog log = await _dayLog.read();
    if (mounted) {
      setState(() => _log = log);
    }
  }

  Future<void> _readChallenges() async {
    final int served = await widget.seriesCursor.read();
    if (mounted) {
      setState(() => _challenges = served);
    }
  }

  /// **Re-read on every visit, like the day log and for the same reason.** The
  /// round writes an answer while this root sits behind an `IndexedStack`, so a
  /// record read once at launch is an accuracy from launch time — the staleness
  /// `_refreshOnComingToTheFront` exists to fix, arriving through a second
  /// source (PROC-13).
  Future<void> _readAnswerRecord() async {
    final List<AnsweredItem> record = await _answerRecord.read();
    if (mounted) {
      setState(() => _stats = LocalStats.of(record));
    }
  }

  Future<void> _askForHistory() async {
    final LinkedSession? session = widget.session;
    if (session == null) {
      return;
    }
    final HistoryResult result =
        await (widget.fetchHistory ?? _historyOverASocket)(session.accessToken);
    if (!mounted) {
      return;
    }
    setState(() => _history = result);
  }

  Future<HistoryResult> _historyOverASocket(String accessToken) async {
    final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
    try {
      return await api.getHistory(accessToken);
    } finally {
      api.close();
    }
  }

  /// Links whenever a session appears, rather than when a screen calls back.
  ///
  /// **The session is the trigger, not the sign-in.** A route that linked from
  /// the auth flow's callback would leave any other way of getting a session —
  /// a restored one, a second root — with an account and no player, which is
  /// exactly the state the app sat in before this existed.
  void _linkIfNeeded(LinkedSession? before) {
    final LinkedSession? session = widget.session;
    if (session == null || session.accessToken == before?.accessToken) {
      return;
    }
    unawaited(_link(session));
  }



  /// What the AkiMath server said when asked who this token belongs to.
  ///
  /// **The account is only half the chain.** A verified Neon Auth account with
  /// a JWT proves the provider works; it proves nothing about whether our own
  /// server accepts that token. So the flow's last act is to ask.
  ///
  /// Held as a state rather than a sentence: the copy, the hue and whether
  /// there is a retry are `features/states/`, and a screen that assembled them
  /// inline would grow a branch per case and miss the one nobody writes —
  /// loading, which is not a `MeResult` at all.
  AccountState _accountState = AccountState.none;


  /// Attaches this device's player, then asks the server who that is.
  ///
  /// **Linking first, and on every sign-in.** An account with no player is the
  /// state the app used to sit in for ever — nothing called `POST /players/link`
  /// — so `GET /me` answered 404, and every other operation would have too.
  /// It is idempotent by nature (the row it would write is the row already
  /// there), so a returning device re-attaches rather than needing to know
  /// whether it linked before.
  ///
  /// **One round trip, because the link already answers with the profile.**
  /// `POST /players/link` returns the frozen `Me` — that *is* the server's
  /// word, so asking `GET /me` straight afterwards would be the same question
  /// twice. The lookup stays for the retry path, where a failed one can be
  /// asked again.
  Future<void> _link(LinkedSession session) async {
    setState(() => _accountState = AccountState.loading);

    final String playerId =
        await (widget.playerIds ?? const PrefsPlayerIdStore()).readOrMint();
    final LinkResult linked = await (widget.link ?? _linkOverASocket)(
      accessToken: session.accessToken,
      playerId: playerId,
      ageBand: session.ageBand,
    );
    if (!_stillOn(session)) {
      return;
    }
    if (linked is! LinkConflict) {
      setState(() => _accountState = linkStateFor(linked));
      return;
    }
    await _refineConflict(session, playerId);
  }

  /// Asks which of the two conflicts the 409 was.
  ///
  /// **A second round trip, and only on the path that needs one.** The 409's
  /// body distinguishes them in an English `message` and nothing else, so
  /// reading it would let a copy edit on the server change what a player is
  /// told. `GET /me` answers the same question in the contract's own terms —
  /// see `conflictStateFor` for why the inference is exact.
  Future<void> _refineConflict(LinkedSession session, String playerId) async {
    final MeResult probe = await _whoAmI(session.accessToken);
    if (!_stillOn(session)) {
      return;
    }
    setState(() => _accountState =
        conflictStateFor(probe: probe, devicePlayerId: playerId));
  }

  /// Whether the answer that just arrived is still about the session on screen.
  ///
  /// **`mounted` is not enough once there are two awaits.** A session can
  /// arrive while the probe is in flight — the shell holds it and this root
  /// stays alive behind an `IndexedStack` — and writing the old session's
  /// verdict over the new one's would put a conflict banner on an account that
  /// never had a conflict (PROC-13).
  bool _stillOn(LinkedSession session) =>
      mounted && widget.session?.accessToken == session.accessToken;

  Future<LinkResult> _linkOverASocket({
    required String accessToken,
    required String playerId,
    required AgeBand ageBand,
  }) async {
    final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
    try {
      return await api.linkPlayer(
        accessToken: accessToken,
        playerId: playerId,
        ageBand: ageBand,
        // The contract requires the header and the server ignores its value:
        // linking is idempotent by nature rather than by a replay store. The
        // player id is the one thing that is stable across this device's
        // retries and unique to it.
        idempotencyKey: 'link:$playerId',
      );
    } finally {
      api.close();
    }
  }

  Future<void> _askWhoIAm(String accessToken) async {
    setState(() => _accountState = AccountState.loading);

    final MeResult result = await _whoAmI(accessToken);
    if (!mounted) {
      return;
    }
    setState(() => _accountState = accountStateFor(result));
  }

  /// One lookup, used by the retry here and by the sign-in door's band.
  ///
  /// **Both had to be the same call.** The flow asks who a token belongs to in
  /// order to read the band the server stores; this route asks the same
  /// question to redraw the account section. Two spellings of `GET /me` is two
  /// places to change the day it moves.
  Future<MeResult> Function(String accessToken) get _whoAmI =>
      widget.whoAmI ?? _meOverASocket;

  Future<MeResult> _meOverASocket(String accessToken) async {
    final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
    try {
      return await api.getMe(accessToken);
    } finally {
      api.close();
    }
  }

  /// The one destructive act, and it is a full screen rather than a dialog.
  ///
  /// The question needs a sentence about what survives the call — the address
  /// stays registered with the identity provider, which is not ours to delete —
  /// and that does not fit in an alert. It is also not a surface this app draws.
  void _openEraseFlow() {
    final String token = widget.session!.accessToken;
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext _) => AppShell(
        child: EraseAccountRoute(
          erase: () async {
            final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
            try {
              return await api.eraseMe(token);
            } finally {
              api.close();
            }
          },
          onClose: (bool erased) {
            Navigator.of(context).pop();
            if (!erased || !mounted) {
              return;
            }
            // Forgotten here as well as there. Leaving the address on screen
            // after the row is gone would be the app disagreeing with the
            // server about whether this device is linked.
            setState(() => _accountState = AccountState.none);
            widget.onSessionChanged?.call(null);
          },
        ),
      ),
    ));
  }

  /// Opens the account flow on the door the player pressed.
  ///
  /// **Two doors, one flow.** Creating an account and coming back to one are
  /// different errands and the sign-in one used to be four screens deep, behind
  /// a birth date nobody coming back should be asked for.
  void _openAccountFlow(AuthEntry entry) {
    // Only what this route opened is this route's to close. An injected
    // provider belongs to whoever handed it over.
    final AuthClient? own = widget.auth == null
        ? AuthClient(baseUrl: Uri.parse(widget.authBaseUrl))
        : null;
    final AuthApi auth = own ?? widget.auth!;
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext _) => AppShell(
        child: AuthFlow(
          auth: auth,
          whoAmI: _whoAmI,
          entry: entry,
          // The provider's own origin: the only one it trusts while
          // `trusted_origins` is empty. See `Endpoints.callbackUrl`.
          callbackUrl: widget.authBaseUrl,
          today: widget.now(),
          onLinked: (LinkedAccount account) {
            own?.close();
            if (!mounted) {
              return;
            }
            widget.onSessionChanged?.call(LinkedSession(
              email: account.email,
              accessToken: account.accessToken,
              ageBand: account.ageBand,
              provider: account.provider,
            ));
            Navigator.of(context).pop();
            // The linking follows from the session existing — see
            // `didUpdateWidget` — rather than from this callback, so a session
            // that arrives any other way is linked too.
          },
          onGaveUp: () {
            own?.close();
            Navigator.of(context).pop();
          },
        ),
      ),
    ));
  }

  /// Pushes a settings screen onto the tab's own navigator.
  ///
  /// **Not `fullScreenSession`.** That route exists to make a *session* — a
  /// round, a board — take the whole screen with no way out but finishing. The
  /// group badge over `4.1`–`4.7` says the opposite: *"Aquí sí va la barra
  /// inferior."* So these push under the bar, and the back control is a pop
  /// rather than a flag on the root.
  void _push(Widget Function(VoidCallback back) build) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (BuildContext pushed) =>
          build(() => Navigator.of(pushed).pop()),
    ));
  }

  void _openSettings() => _push(
        (VoidCallback back) => AppShell(
          child: SettingsListScreen(
            onBack: back,
            onOpenAccount: _openAccountDetail,
            onOpenLegend: () => _push(
              (VoidCallback back) => AppShell(child: LegendScreen(onBack: back)),
            ),
          ),
        ),
      );

  void _openAccountDetail() {
    final String? email = widget.session?.email;
    if (email == null) {
      return;
    }
    _push(
      (VoidCallback back) => AppShell(
        child: AccountScreen(
          onBack: back,
          email: email,
          // Only where a session exists that the request could travel on.
          // `erasureOffered` is the judgement; the token is the fact.
          onErase: erasureOffered(_accountState) ? _openEraseFlow : null,
          onChangePassword: () => _push(
            (VoidCallback back) =>
                AppShell(child: ChangePasswordScreen(onBack: back)),
          ),
          // Unconditional, because this screen only opens with a session:
          // `_openAccountDetail` returns before pushing when there is no
          // address to show.
          onSignOut: _signOut,
        ),
      ),
    );
  }

  /// Forgets the session and leaves the account's own stack.
  ///
  /// **The same two statements the erasure success path runs**, because the
  /// same thing is true afterwards: this device is not signed in. The shell
  /// owns the session (`RootScaffold`), so `onSessionChanged(null)` is the only
  /// thing that actually forgets it — clearing this route's state alone would
  /// leave the home flushing its journal under a token the player asked us to
  /// drop.
  ///
  /// **Nothing device-local goes with it, and that is the decision.** Unlinked
  /// play is entirely offline (ADR 0002), so the days practised, the run, the
  /// challenge count and the answers waiting to sync all belong to a player who
  /// need never have had an account. A row labelled *Cerrar sesión* that
  /// deleted them would be a destructive act wearing a non-destructive label —
  /// the destructive door is `Eliminar mi cuenta`, two rows down, behind a
  /// typed `BORRAR`.
  ///
  /// **It pops to the root rather than back one screen.** `Cuenta` is a
  /// screen about an account this device no longer has, and the row above it in
  /// `4.2` opens nothing without a session — landing on either would be leaving
  /// the player somewhere that has stopped being true.
  void _signOut() {
    Navigator.of(context).popUntil((Route<Object?> route) => route.isFirst);
    setState(() => _accountState = AccountState.none);
    widget.onSessionChanged?.call(null);
  }

  /// Every figure `4.1` prints, and **not one of them is invented any more.**
  ///
  /// The days and the run come from `DayLog`, the count of challenges from the
  /// series cursor the home advances, and accuracy and mean time from the
  /// record of what this device actually answered. Zero, or absent, before a
  /// store answers and the same for a player who has never played — which is
  /// why nothing here waits on any of them.
  ///
  /// **What is left out is left out on purpose.** A rating is not passed
  /// because there is no single number to pass: `GET /me/standing` answers one
  /// **per skill**, an unrated player is the ordinary case, and this client
  /// cannot so much as name a skill. A weekly move is not passed because
  /// `HistoryEntry.ratingDelta` is a movement per *session* and per *skill*
  /// rather than per week: a week of them summed adds independent scales, and
  /// the two kinds that report null — a session spanning two skills, a session
  /// that only calibrated — would drop out of the sum instead of counting as
  /// nothing. `+ 36 esta semana` still has no source at
  /// all. Both stay absent rather than becoming a plausible average or a `± 0`,
  /// which is the same rule that makes `HISTORIAL` disappear when there is
  /// nothing true to say.
  ///
  /// **No request is made for either.** A `GET /me/standing` whose answer this
  /// screen has decided it cannot draw is a round trip that buys nothing, and a
  /// client operation with no caller is a claim about the app that is not true.
  ProfileFigures _figures() => ProfileFigures(
        daysPractised: _log.days.length,
        streakDays: streakLength(attemptDays: _log.days, today: widget.now()),
        challenges: _challenges,
        accuracyPercent: _stats.accuracyPercent,
        averageTime: _stats.meanTime,
      );

  /// Whether making an account is worth offering.
  ///
  /// A build with no endpoints can reach no provider, and a device that already
  /// has a session has one already.
  bool get _offerToCreate =>
      widget.authBaseUrl.isNotEmpty && widget.session == null;

  /// Whether signing in is worth offering.
  ///
  /// **The same cases, plus a refused session.** `AccountState.rejected` means
  /// the account is real and this device's token is not; `4.1` says
  /// *"Vuelve a entrar"* and used to offer nothing that could, because the door
  /// required there to be no session at all. The session is in memory, so the
  /// only recovery left was force-quitting the app.
  bool get _offerToSignIn =>
      widget.authBaseUrl.isNotEmpty &&
      (widget.session == null || _accountState == AccountState.rejected);

  /// What asking again should ask, where asking again is offered at all.
  ///
  /// **A refused link is retried by linking, not by `GET /me`.** The two are
  /// different questions and the wrong one answers wrongly: a mismatch whose
  /// account holds no player would come back `noPlayer` — *"Cuenta lista. Falta
  /// vincular un jugador"* — which is a cheerful way of saying the link that
  /// just failed has not been tried.
  VoidCallback? get _accountRetry {
    final LinkedSession? session = widget.session;
    if (session == null) {
      return null;
    }
    return switch (accountDoorFor(_accountState)) {
      AccountDoor.retry when _accountState == AccountState.mismatch =>
        () => unawaited(_link(session)),
      AccountDoor.retry ||
      // `4.10` needs the retry to hand on to the screen it opens.
      AccountDoor.detail => () => unawaited(_askWhoIAm(session.accessToken)),
      AccountDoor.none || AccountDoor.signOut => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    // **`noAccount` before anything else.** With no session there is no request
    // in flight, so `loading` would be a wait for something nobody asked for.
    final HistoryState history = widget.session == null
        ? HistoryState.noAccount
        : historyStateFor(_history);
    final HistoryResult? result = _history;

    return AppShell(
      child: ProfileScreen(
        accountEmail: widget.session?.email,
        accountState: _accountState,
        onOpenSettings: _openSettings,
        figures: _figures(),
        historyState: history,
        entries: result is HistoryFound
            ? result.history.entries
            : const <HistoryEntry>[],
        onRetryHistory: canRetryHistory(history)
            ? () {
                setState(() => _history = null);
                unawaited(_askForHistory());
              }
            : null,
        // Only offered where retrying could change the answer. A retry on a
        // refused session would fetch the same refusal.
        onRetryAccount: _accountRetry,
        // **Offered where the policy says it is the way out, not wherever it
        // is possible.** Signing out works with any session; it *answers*
        // exactly one state — the progress on this phone belonging to another
        // account — and a door on every screen is a door nobody reads. Ajustes
        // keeps the unconditional row.
        onSignOut: accountDoorFor(_accountState) == AccountDoor.signOut
            ? _signOut
            : null,
        // Absent rather than broken when the build was given no endpoints.
        onCreateAccount: _offerToCreate
            ? () => _openAccountFlow(AuthEntry.createAccount)
            : null,
        // **The returning player's door, and it is on the root.** It used to
        // exist only as a text link at the bottom of the sign-up form, three
        // screens and a birth date past this point.
        onSignIn:
            _offerToSignIn ? () => _openAccountFlow(AuthEntry.signIn) : null,
      ),
    );
  }
}
