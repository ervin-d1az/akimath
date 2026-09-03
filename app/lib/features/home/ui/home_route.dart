import 'dart:async';

import 'package:flutter/material.dart';

import '../../../content/model/diagnosis.dart';
import '../../../content/model/item.dart';
import '../../../content/model/pack.dart';
import '../../../content/pack_reader.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/spec/verdict.dart';
import '../../round/policy/series_plan.dart';
import '../../round/policy/streak_policy.dart';
import '../data/day_log_store.dart';
import '../data/prefs_day_log_store.dart';
import '../data/series_cursor_store.dart';
import '../policy/day_log.dart';
import '../policy/puzzle_menu.dart';
import '../policy/puzzle_of_day.dart';
import '../policy/series_families.dart';
import '../../round/ui/round_screen.dart';
import '../../round/ui/summary/series_summary_screen.dart';
import '../../shell/policy/visible_tabs.dart';
import '../../shell/ui/app_shell.dart';
import '../../../content/model/puzzle.dart';
import '../../puzzle/ui/puzzle_screen.dart';
import '../../puzzle/ui/puzzle_solved_screen.dart';
import '../../puzzle/ui/word_search_screen.dart';
import '../../../api/api_client.dart';
import '../../../api/endpoints.dart';
import '../../account/policy/session.dart';
import '../../shell/ui/skeleton_block.dart';
import '../../sync/attempt_sync.dart';
import '../../sync/data/issued_pack_store.dart';
import '../../sync/policy/pack_in_play.dart';
import '../../sync/policy/pack_refresh.dart';
import '../../stats/data/answer_record_store.dart';
import '../../stats/policy/local_stats.dart';
import '../../states/data/streak_notice_store.dart';
import '../../states/policy/account_state.dart';
import '../../states/policy/streak_notice.dart';
import '../../states/ui/streak_at_risk_screen.dart';
import '../../states/policy/offline_bag.dart';
import '../../states/ui/offline_screen.dart';
import '../../states/ui/streak_lost_screen.dart';
import '../policy/broken_run.dart';
import '../policy/offline_notice.dart';
import '../policy/streak_state.dart';
import 'home_screen.dart';

/// Loads the pack, shows the home, and pushes the series.
///
/// **The IO and the clock live here so `HomeScreen` has neither.** The screen
/// takes an item to preview and a streak count; this route is what reads the
/// bundled pack and asks `StreakPolicy` what today makes of the days it knows.
///
/// It is also `fullScreenSession`'s first real caller. Declared rule 1 says a
/// series takes the whole screen with no navigation affordance, and routing it
/// is what makes that structural rather than something each screen remembers.
class HomeRoute extends StatefulWidget {
  const HomeRoute({
    super.key,
    this.reader = const PackReader(),
    this.now = DateTime.now,
    this.dayLog,
    this.seriesCursor = const SeriesCursorStore(),
    this.streakNotices,
    this.session,
    this.account = AccountState.none,
    this.sync,
    this.issuePack,
    this.fetchPack,
    this.issuedPacks,
    this.answerRecord,
    this.visibility = RootVisibility.showing,
  });

  /// Whether this root is the one on screen.
  ///
  /// **A day practised elsewhere reaches the streak only here.** `_refreshLog`
  /// runs when a series or a board *this route pushed* comes back, and a
  /// practice run started from Mapa is neither — it records the day into the
  /// same `DayLogStore` this reads, while `IndexedStack` keeps the home alive
  /// with no second `initState` to hook (PROC-13).
  ///
  /// Defaults to [RootVisibility.showing], the same default and for the same
  /// reason `ProfileRoute` gives it: every caller that is not the shell is
  /// looking at it.
  final RootVisibility visibility;

  /// The account this device is signed in to, if it is.
  ///
  /// **The home needs it for one reason**: an answered item is only worth
  /// remembering when there is somewhere to send it. Unlinked play is entirely
  /// offline (ADR 0002) and journalling it would file a batch nothing could
  /// ever accept.
  final LinkedSession? session;

  /// Where the account stands with the server, as the profile last found it.
  ///
  /// **A session is not a player, and issuing needs the player.** `POST /packs`
  /// resolves it from the session and 404s when the account holds none — so a
  /// launch that asks on the session alone races `POST /players/link`, which
  /// the profile fires off the very same event this route reacts to. Measured
  /// against the deployed server on 2026-09-02: the two started 15 ms apart,
  /// issuing lost, and the device played the bundled pack for the rest of the
  /// process with nothing it produced syncable.
  ///
  /// Held by `RootScaffold` for the reason the session is — the profile links
  /// and the home plays, and their common ancestor is the only place that can
  /// hold what both of them need. [packAccountFor] is what reads it.
  final AccountState account;

  /// What remembers an answered item until the server has it.
  ///
  /// Injected so a widget test never reaches a plugin or a socket.
  final AttemptSync? sync;

  /// Asks the server for a pack. A closure, the same shape every other request
  /// in this app takes and for the same reason: a `testWidgets` runs in a
  /// fake-async zone and a real socket inside one hangs on `!timersPending`.
  final Future<IssueResult> Function(String accessToken)? issuePack;

  /// Fetches the pack this device already has an id for.
  final Future<FetchPackResult> Function({
    required String accessToken,
    required String packId,
  })? fetchPack;

  /// Where the id of that pack is kept between launches.
  final IssuedPackStore? issuedPacks;

  /// Where the device's own record of answered items is kept.
  ///
  /// **The practice round writes to it and `Primer reto` does not**, which is
  /// the rule `AnswerRecordStore` states: the teaching item is built with no
  /// round callbacks at all, so there is nothing to record into rather than a
  /// rule somebody has to remember.
  ///
  /// **This route is not the only place that keeps it.** `MapRoute` records a
  /// topic's practice and `OnboardingFlow` records the calibration probe, and
  /// this comment claimed the opposite while the second of those was missing
  /// entirely (CMT-4). Nothing gates the claim, which is
  /// `docs/solid/shell-and-entry.md`'s finding 1: grep `AnswerRecordStore`
  /// across `lib/` rather than believing a sentence.
  ///
  /// Injected for the reason [dayLog] is — a `testWidgets` must never reach a
  /// plugin.
  final AnswerRecordStore? answerRecord;

  final PackReader reader;
  final DateTime Function() now;

  /// Where the days practised are kept.
  ///
  /// Defaults to the device's own storage, so the streak survives a relaunch.
  /// Tests hand in an in-memory store instead — the seam is why swapping it is
  /// a constructor argument and nothing else.
  final DayLogStore? dayLog;

  /// How many items the player has already been served, so a second series is
  /// not the first series again. Persisted, or a relaunch would repeat it.
  final SeriesCursorStore seriesCursor;

  /// Where the page-turn record lives.
  ///
  /// Defaults to the device's own, so `4.13` is turned once and not once per
  /// launch. Injected for the same reason [dayLog] is: a test that had to write
  /// a preference to seed a screen would be testing the preference.
  final StreakNoticeStore? streakNotices;

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> {
  late final Future<Pack> _pack = widget.reader.load();
  late final DayLogStore _dayLog = widget.dayLog ?? const PrefsDayLogStore();
  late final StreakNoticeStore _notices =
      widget.streakNotices ?? const PrefsStreakNoticeStore();
  DayLog _log = DayLog.empty;

  /// Whether the launch's streak notice has been dealt with.
  ///
  /// **A launch-scoped latch, not a second record.** `_refreshLog` runs again
  /// every time a series or a board returns, and without this the same screen
  /// would be pushed on top of the home each time the player came back — which
  /// is `4.12`'s case exactly, since nothing about it is stored on purpose.
  bool _noticeSettled = false;

  /// Whether this launch's `4.9` has been settled, shown or not.
  ///
  /// The same launch-scoped latch `_noticeSettled` is, and for the same reason:
  /// nothing about being offline is recorded on purpose, so without it a pack
  /// request answering late would be free to push a second time.
  bool _offlineSettled = false;

  /// How many full-screen sessions this route has open.
  ///
  /// **`4.9` is the only screen here that nobody asked for, so it is the only
  /// one that has to check.** A dead network usually answers by timing out,
  /// which is minutes — long after the player tapped `Empezar la serie` — and
  /// declared rule 1 gives a session exactly one way out and no interruptions.
  ///
  /// **A count and not a flag, though it has one reader.** The read happens
  /// once, at whatever moment the network gives up, and what it needs to know
  /// is whether *anything* is up — a bool would have to be set and cleared by
  /// each of the three pushes, which is three places to get wrong instead of
  /// the one [_openSession] gives it.
  int _sessionsOpen = 0;

  late final AttemptSync _sync = widget.sync ?? AttemptSync();

  late final AnswerRecordStore _answerRecord =
      widget.answerRecord ?? const PrefsAnswerRecordStore();

  /// The pack the server issued, once it has.
  ///
  /// **Null is the ordinary state**, and it is what an unlinked device plays
  /// on for ever: unlinked play is entirely offline (ADR 0002), so there is
  /// nothing to ask and nothing to send. When it is not null it *replaces* the
  /// bundled pack — same six families, same boards, and an address on every
  /// item, which is the whole difference.
  Pack? _issued;

  late final IssuedPackStore _issuedPacks =
      widget.issuedPacks ?? const PrefsIssuedPackStore();

  /// How many items have been served, held here as well as read in
  /// `_startSeries`, because the home now *shows* what the next series holds
  /// and cannot await a store while building. Refreshed with the log, so
  /// returning from a series updates both.
  int _itemsServed = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  /// Opens a full-screen session, and counts it while it is up.
  ///
  /// Every push this route makes goes through here, so [_sessionsOpen] cannot
  /// drift away from what is on screen by somebody adding a fourth caller.
  Future<T?> _openSession<T>(BuildContext context, WidgetBuilder builder) async {
    _sessionsOpen += 1;
    try {
      return await pushSession<T>(context, builder);
    } finally {
      _sessionsOpen -= 1;
    }
  }

  /// The launch: read what is stored, then show what it owes.
  ///
  /// **In that order, and only here.** `_refreshLog` runs again on every return
  /// from a series or a board; the notice must not. Deciding it before the log
  /// is read would decide it from an empty one, which is `StreakNotice.none`
  /// for every player.
  Future<void> _open() async {
    // **Before anything else, and never waited on.** A batch may have been
    // waiting since a bus ride days ago; sending it is not something a player
    // should watch, and a failure leaves the journal exactly as it was.
    unawaited(_flush());
    // **Started here and read last.** The request must not hold up the home or
    // the streak notice — both draw on what is already on the device — and
    // `4.9` must not land on top of either, so its answer is the last thing
    // this launch waits on. Total order beats a race between two pushes.
    final Future<PackAsk> asked = _askForPack();
    await _refreshLog();
    if (!mounted) {
      return;
    }
    await _showNoticeIfDue();
    if (!mounted) {
      return;
    }
    await _tellOfflineIfDue(await asked);
  }

  Future<void> _refreshLog() async {
    final DayLog log = await _dayLog.read();
    final int served = await widget.seriesCursor.read();
    if (!mounted) {
      return;
    }
    setState(() {
      _log = log;
      _itemsServed = served;
    });
  }

  /// Re-reads the day log the moment this root becomes the one on screen.
  ///
  /// **A rebuild is not a visit**, which is `ProfileRoute`'s wording because it
  /// is the same problem. The transition is what matters: behind, then showing.
  void _refreshOnComingToTheFront(RootVisibility before) {
    if (widget.visibility == RootVisibility.showing &&
        before == RootVisibility.behind) {
      unawaited(_refreshLog());
    }
  }

  @override
  void didUpdateWidget(HomeRoute old) {
    super.didUpdateWidget(old);
    // **A day can be practised on another tab.** Mapa starts a practice run
    // against this same store, and nothing here pushed it — so returning to
    // Inicio is the only moment the streak can catch up (PROC-13).
    _refreshOnComingToTheFront(old.visibility);
    // **The session arrives after this screen is built.** A player links on the
    // profile tab, and `IndexedStack` keeps the home alive — so `initState` has
    // long since run and a journal filled offline would sit there for ever.
    // This is the same reading `ProfileRoute` needed for its history.
    if (widget.session?.accessToken != old.session?.accessToken) {
      unawaited(_flush());
    }
    _askAgainIfTheAccountMoved(old);
  }

  /// Asks for a pack whenever either half of *who is asking* changes.
  ///
  /// **One call for two triggers, because both can land in the same frame.**
  /// The shell holds the session and the account and a single `setState` can
  /// move both — a restored credential the profile links straight away — and
  /// two `if`s each firing a request would put two packs in flight with no
  /// guard between them.
  ///
  /// **The account is the trigger this route was missing.** Waiting on the
  /// session alone is the race: the profile links off that same event, so the
  /// pack request and the link start together and the pack request loses.
  ///
  /// **The answer is dropped here, where `_open` reads it.** A session appears
  /// while a player is on the profile tab, so this route is alive and
  /// invisible; a full-screen notice over another tab is not something a
  /// background request gets to do. The link itself also just proved the
  /// network works, so a blip on the very next request is not a state.
  void _askAgainIfTheAccountMoved(HomeRoute old) {
    if (widget.session?.accessToken == old.session?.accessToken &&
        widget.account == old.account) {
      return;
    }
    unawaited(_askForPack());
  }

  /// Asks for a pack, once, when there is a **player** to ask for one.
  ///
  /// **A session is not a player, and that distinction is the whole of it.**
  /// `POST /packs` resolves the player from the session and 404s when the
  /// account holds none, and the profile writes that row off the very same
  /// event this route reacts to — so asking on the session alone is a race
  /// this route loses, silently and for the rest of the process. Measured
  /// against the deployed server on 2026-09-02: 404 at 02:52:17.602, the link
  /// 200 at .624, and a five-item series afterwards that reached `attempts` as
  /// nothing at all. [packAccountFor] is what tells the two apart.
  ///
  /// **Held in memory once it lands, and its id on disk.** The server says a
  /// second pack is harmless — issuing is not idempotent by nature and
  /// retention sweeps what lapses — but a row per launch per player is waste
  /// with a cheaper answer: the id is stored and `GET /packs/{packId}` rebuilds
  /// the same pack byte for byte, which is the `fetch` branch below.
  ///
  /// **A failure is silent and the bundled pack keeps playing.** There is
  /// nothing useful to tell a player about a request they did not make, and the
  /// app they already had works — with one exception, which is what the return
  /// value is for: nothing answering at all is the only evidence this app ever
  /// gets that the device is offline, and `4.9` is built to say so.
  Future<PackAsk> _askForPack() async {
    final LinkedSession? session = widget.session;
    if (session == null || _issued != null) {
      return PackAsk.notAsked;
    }

    // **The decision is `packRefresh`'s and this only carries it out.** Three
    // branches — nothing, fetch, issue — and the third is also where a fetch
    // that came back 404 lands, because that is the one answer meaning *there
    // is no such pack for you*.
    final String? stored = await _issuedPacks.read();
    if (!mounted) {
      return PackAsk.notAsked;
    }
    final PackRefresh owed = packRefresh(
      account: packAccountFor(widget.account),
      storedPackId: stored,
      // The device knows the id and not the window: it stores one and not the
      // other. A lapsed pack costs a round trip to be told so, which is cheaper
      // than a second thing that can disagree with the row.
      expiresAt: null,
      now: widget.now(),
    );
    if (owed == PackRefresh.none) {
      return PackAsk.notAsked;
    }
    // **One request at a time, and the latch sits *after* the decision.** The
    // account moves through more than one state on a first launch — `none`,
    // then `loading`, then `linked` — and each move asks again, so two passes
    // can overlap on the store read above and both come out wanting a pack.
    // Latching the whole method instead would let a pass that decided `none`
    // shut out the pass that decided `issue`, which loses the trigger rather
    // than saving a request.
    if (_requesting) {
      return PackAsk.notAsked;
    }
    _requesting = true;
    try {
      return await _carryOut(owed, session: session, storedPackId: stored);
    } finally {
      _requesting = false;
    }
  }

  /// Whether a pack request is in flight. See [_askForPack] for why.
  bool _requesting = false;

  /// Performs the request [packRefresh] decided on. It decides nothing itself.
  Future<PackAsk> _carryOut(
    PackRefresh owed, {
    required LinkedSession session,
    required String? storedPackId,
  }) async {
    switch (owed) {
      case PackRefresh.none:
        // Settled by the caller, which never reaches here with it — repeated
        // rather than defaulted, so a fourth branch is a compile error.
        return PackAsk.notAsked;
      case PackRefresh.fetch:
        final FetchPackResult fetched = await (widget.fetchPack ?? _fetchOverASocket)(
          accessToken: session.accessToken,
          packId: storedPackId!,
        );
        if (fetched is FetchPackDone && mounted) {
          _adopt(fetched.issued);
          return fetchAsk(fetched);
        }
        if (fetched is! FetchPackGone || !mounted) {
          // Refused, broken or unreachable: the id is still good and the
          // bundled pack still plays. Issuing here would mint a row for a
          // network blip. The answer still travels — `fetchAsk` is the one
          // place that decides which of them means no signal.
          return fetchAsk(fetched);
        }
        await _issuedPacks.clear();
        if (!mounted) {
          return fetchAsk(fetched);
        }
        return _issueAndKeep(session);
      case PackRefresh.issue:
        return _issueAndKeep(session);
    }
  }

  Future<PackAsk> _issueAndKeep(LinkedSession session) async {
    final IssueResult result =
        await (widget.issuePack ?? _issueOverASocket)(session.accessToken);
    if (mounted && result is IssueDone) {
      // **Written before it is adopted.** A device that plays a pack it did not
      // record would issue another next launch, and the row it just made would
      // be one nobody ever fetches.
      await _issuedPacks.write(result.issued.packId);
      if (mounted) {
        _adopt(result.issued);
      }
    }
    return issueAsk(result);
  }

  /// Reads an issued pack and starts playing it.
  ///
  /// **A pack this app cannot read is a pack it does not play**, and that is
  /// `packFrom`'s rule rather than this screen's — the map adopts a pack too,
  /// and the two had written the same `try`/`on FormatException` out by hand.
  void _adopt(IssuedPack issued) {
    final Pack? pack = packFrom(issued);
    if (pack != null) {
      setState(() => _issued = pack);
    }
  }

  Future<FetchPackResult> _fetchOverASocket({
    required String accessToken,
    required String packId,
  }) async {
    final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
    try {
      return await api.fetchPack(accessToken: accessToken, packId: packId);
    } finally {
      api.close();
    }
  }

  Future<IssueResult> _issueOverASocket(String accessToken) async {
    final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
    try {
      return await api.issuePack(accessToken);
    } finally {
      api.close();
    }
  }

  /// Sends what the journal is holding, if there is a session to send it on.
  ///
  /// Failure is the journal's business rather than this screen's: `journalAfter`
  /// already decides what survives which answer, and there is nothing useful to
  /// say to a player about a batch they never asked to send.
  Future<void> _flush() async {
    final LinkedSession? session = widget.session;
    if (session == null) {
      return;
    }
    await _sync.flush(session.accessToken);
  }

  /// Shows the streak screen this launch owes, if it owes one.
  ///
  /// **Pushed over the home rather than shown instead of it.** The design draws
  /// both as full screens with a single forward action, and `4.13` is annotated
  /// *"se pasa la página"* — a page turns onto something. Pushing also means
  /// the action can start a series through the machinery this route already
  /// has, rather than a second copy of it living wherever the screen was.
  ///
  /// `fullScreenSession` is the same mechanism a series and a board use, which
  /// is what makes "no navigation affordance" structural.
  Future<void> _showNoticeIfDue() async {
    if (_noticeSettled) {
      return;
    }
    // **Set before the first await.** A guard and a set straddling one is two
    // callers both passing, and both pushing.
    _noticeSettled = true;

    final DateTime now = widget.now();
    final DateTime? shown = await _notices.lostShownOn();
    if (!mounted) {
      return;
    }

    final StreakNotice notice = streakNoticeFor(
      state: streakStateFor(attemptDays: _log.days, now: now),
      lostShownOn: shown,
      now: now,
    );
    if (notice == StreakNotice.none) {
      return;
    }

    if (notice == StreakNotice.lost) {
      // **Recorded on showing, not on dismissing.** A player who closes the app
      // from this screen has seen the page turn; asking them to acknowledge it
      // before it counts would show it again tomorrow for no reason.
      await _notices.markLostShown(now);
      if (!mounted) {
        return;
      }
    }

    bool solve = false;
    await _openSession<void>(context, (BuildContext noticeContext) {
      void leave({required bool andSolve}) {
        solve = andSolve;
        Navigator.of(noticeContext).pop();
      }

      return switch (notice) {
        StreakNotice.atRisk => StreakAtRiskScreen(
          days: streakLength(attemptDays: _log.days, today: now),
          left: hoursLeftToday(now),
          onSolve: () => leave(andSolve: true),
          onLater: () => leave(andSolve: false),
        ),
        StreakNotice.lost => StreakLostScreen(
          brokenRun: brokenRunLength(attemptDays: _log.days, now: now),
          onStart: () => leave(andSolve: true),
        ),
        StreakNotice.none => const SizedBox.shrink(),
      };
    });

    if (solve && mounted) {
      final Pack pack = await _pack;
      if (mounted) {
        await _startSeries(context, pack);
      }
    }
  }

  /// Shows `Sin conexión` when the launch's request went nowhere.
  ///
  /// **The trigger is evidence, not a guess.** The only network fact this route
  /// ever learns is what its pack request came back as, and `PackAsk` decides
  /// which of those means no signal — the same call `accountStateFor` makes for
  /// the profile. A refusal, a 5xx or a 404 is the server *talking*, so none of
  /// them is this screen.
  ///
  /// **It counts the pack that is actually in play**, which is why `4.9` is
  /// pushed from here and from nowhere else: the profile cannot know whether
  /// the bundled pack or an issued one is loaded, and the headline is a count.
  ///
  /// A player with no account never sees it, and that is not an omission —
  /// unlinked play makes no request, so there is nothing to be evidence of, and
  /// a permanent notice over the ordinary state of the app would say nothing
  /// true.
  Future<void> _tellOfflineIfDue(PackAsk ask) async {
    if (_offlineSettled || ask != PackAsk.nothingAnswered) {
      return;
    }
    // Set before the first await, for the reason `_showNoticeIfDue` sets its
    // own: a guard and a set straddling one is two callers both passing.
    _offlineSettled = true;

    final Pack? pack = await _playablePack();
    if (pack == null || !mounted || _sessionsOpen > 0) {
      return;
    }
    // The screen's own precondition, asked rather than reimplemented: with
    // nothing in the bag the headline would read *"TRAES 0 RETOS EN LA
    // BOLSA"*, which helps nobody.
    if (!bagWorthShowing(pack.items.length)) {
      return;
    }

    bool solve = false;
    await _openSession<void>(
      context,
      (BuildContext offlineContext) => OfflineScreen(
        challenges: pack.items.length,
        puzzles: pack.puzzles.length,
        onSolveOffline: () {
          solve = true;
          Navigator.of(offlineContext).pop();
        },
      ),
    );
    if (solve && mounted) {
      await _startSeries(context, pack);
    }
  }

  /// The pack a series would be played from right now, or null when there is
  /// none.
  ///
  /// **The same three refusals `build` draws a message for**: a pack that could
  /// not be read, one whose window has closed, and one the cursor has run past.
  /// `4.9` counts a bag and offers to open it, so on any of the three it would
  /// be wrong twice — a figure about nothing, over a button that returns
  /// immediately from `_startSeries`'s own guard.
  Future<Pack?> _playablePack() async {
    Pack? bundled;
    if (_issued == null) {
      try {
        bundled = await _pack;
      } catch (_) {
        // Deliberately broad, and silent: `build` is already showing the
        // message for an unreadable pack, and a second thing wrong on the same
        // launch is not news to a player.
        return null;
      }
    }
    // Two of the three refusals are `packInPlay`'s, so this and `build` cannot
    // disagree about them — nor can Mapa, which asks the same function.
    final PackInPlay inPlay = packInPlay(
      issued: _issued,
      bundled: bundled,
      now: widget.now(),
    );
    if (inPlay is! PackReady) {
      return null;
    }
    // The third is this route's own: the cursor is what the *series* has
    // served, and no other root serves one.
    final Pack pack = inPlay.pack;
    return seriesPlan(pack.items, from: _itemsServed).isEmpty ? null : pack;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Pack>(
      future: _pack,
      builder: (BuildContext context, AsyncSnapshot<Pack> snapshot) {
        if (snapshot.hasError) {
          return const AppShell(
            child: _HomeMessage('No se pudo abrir el paquete de retos.'),
          );
        }
        // **Which pack is in play is not this screen's to decide.** The issued
        // one wins where there is one — same six families, same boards, and
        // every item carrying a `(packId, index)` the server can grade — and a
        // pack past its window is not played at all. Both halves live in
        // `packInPlay`, because Mapa answers the same question and used to
        // answer it differently: it drew a full map of topics over a pack this
        // screen was already refusing.
        final PackInPlay inPlay = packInPlay(
          issued: _issued,
          bundled: snapshot.data,
          now: widget.now(),
        );
        if (inPlay is! PackReady) {
          return AppShell(
            child: switch (inPlay) {
              PackLapsed() => _HomeMessage(inPlay.message),
              // The bundled pack is still loading, which is the ordinary first
              // frame of a launch.
              PackPending() || PackReady() => const _HomeSkeleton(),
            },
          );
        }
        final Pack pack = inPlay.pack;

        // **The plan the player is about to be served**, not the pack in
        // general. `_startSeries` calls `seriesPlan` with the same cursor, so
        // neither the card nor the row can promise an item the series will not
        // draw. Read once here rather than twice: two calls are two chances to
        // pass a different cursor, which is how the card came to preview
        // `pack.items.first` while the row beside it already read the plan.
        final List<Item> plan = seriesPlan(pack.items, from: _itemsServed);
        if (plan.isEmpty) {
          // Only a pack with no items yields none, and both readers refuse
          // one — so this is the guard `_startSeries` keeps, for the same
          // reason. `HomeScreen.preview` is non-nullable, and `plan.first`
          // would throw here, a screen away from where the pack was read.
          return const AppShell(
            child: _HomeMessage('No se pudo abrir el paquete de retos.'),
          );
        }

        return AppShell(
          child: HomeScreen(
            preview: plan.first,
            streakDays: streakLength(
              attemptDays: _log.days,
              today: widget.now(),
            ),
            weekMarks: weekMarks(attemptDays: _log.days, today: widget.now()),
            todaysFamilies: seriesFamilies(plan),
            // **One card per format**, not one per board: the pack may carry
            // three KenKens, and three cards reading `KenKen` are three cards
            // a player cannot choose between. Which board each opens is the
            // day's, from a pure policy. Empty when the pack carries none,
            // which makes the section absent rather than disabled.
            puzzles: <PuzzleOption>[
              for (final Puzzle puzzle in puzzlesOfDay(
                pack.puzzles,
                today: widget.now(),
              ))
                PuzzleOption(
                  label: puzzleName(puzzle),
                  onOpen: () => _startPuzzle(context, puzzle),
                ),
            ],
            onStart: () => _startSeries(context, pack),
          ),
        );
      },
    );
  }

  /// Pushes the day's board, as a full-screen session.
  ///
  /// The same shape a series gets, and the argument is stronger here: a puzzle
  /// is a longer commitment than five items, so a bottom bar underneath it
  /// would be an invitation to abandon one halfway.
  ///
  /// **It does not flush, where `_startSeries` does.** A board never calls
  /// `_sync.record` — the route records the *day* and nothing else (design
  /// D3) — so coming back from one cannot have changed the journal. A flush
  /// here would only retry a batch some earlier series already tried, on a
  /// trigger that is not evidence of anything new. It belongs in the change
  /// that makes a puzzle leave an attempt row, not before.
  Future<void> _startPuzzle(BuildContext context, Puzzle puzzle) async {
    // **The route holds the clock** (design D3). Neither puzzle screen has one,
    // and adding one to both would be the same decision written twice — the
    // objection that put `onPractised` here rather than a store in each screen.
    //
    // Wall-clock from opening the board, rules-reading included. A puzzle is a
    // sitting, not a reaction test.
    final DateTime startedAt = widget.now();

    await _openSession<void>(context, (BuildContext sessionContext) {
      void leave() => Navigator.of(sessionContext).pop();
      void solved() => _showSolved(sessionContext, puzzle, startedAt);
      // **The route records, the screens report** (design D3). The two
      // formats commit differently — a value on a board, a word claimed —
      // and the same IO decision written into both screens would be free
      // to diverge the first time one of them changed.
      void practised() => unawaited(_dayLog.record(widget.now()));
      // **Exhaustive over the sealed type**, so a sixth format outside
      // `BoardPuzzle` is a compile error rather than a screen that never
      // opens. It replaced an `is! KenKenPuzzle` guard that returned
      // silently for everything else — which left four of the five shipped
      // formats unreachable from the home.
      return switch (puzzle) {
        WordSearchPuzzle() => WordSearchScreen(
          puzzle: puzzle,
          onClose: leave,
          onSolved: solved,
          onPractised: practised,
        ),
        // Every numeric board is the same screen: it takes the board, the
        // pad and the entry policy from the puzzle itself.
        BoardPuzzle() => PuzzleScreen(
          puzzle: puzzle,
          onClose: leave,
          onSolved: solved,
          onPractised: practised,
        ),
      };
    });
    // The puzzle may have recorded today. Re-read rather than add a day to what
    // this screen holds: the store is the source of truth, and a screen that
    // increments locally is how it ends up showing a figure the store would not
    // yield.
    await _refreshLog();
  }

  /// Swaps the finished board for the screen that says so.
  ///
  /// **Replaces rather than stacks** (design D4): the board would still be
  /// underneath, still solved, with nothing left to do to it — so leaving the
  /// completion screen goes home.
  ///
  /// The streak counts today appended to what this screen last read. The day
  /// was recorded the moment the player first committed to the board, so it is
  /// in the store; `_log` may not have been re-read since, and showing a figure
  /// one short of the one the home shows a second later is the
  /// two-screens-one-morning contradiction `StreakPolicy` was fixed for.
  void _showSolved(
    BuildContext sessionContext,
    Puzzle puzzle,
    DateTime startedAt,
  ) {
    final DateTime finishedAt = widget.now();
    // **Both figures are pinned here, not inside the builder.** A route's
    // builder runs when Flutter decides to, which is after this method returns
    // and can be after `_startPuzzle`'s `await` has resumed and refreshed the
    // log — so a figure computed in there is a fact about frame scheduling
    // rather than about the moment the player finished.
    final Duration elapsed = finishedAt.difference(startedAt);
    final int streakDays = streakLength(
      attemptDays: <DateTime>[..._log.days, finishedAt],
      today: finishedAt,
    );

    Navigator.of(sessionContext).pushReplacement(
      fullScreenSession<void>(
        (BuildContext doneContext) => PuzzleSolvedScreen(
          format: puzzleName(puzzle),
          elapsed: elapsed,
          streakDays: streakDays,
          onDone: () => Navigator.of(doneContext).pop(),
        ),
      ),
    );
  }

  /// Pushes a series, and brings the player back when it ends.
  ///
  /// **A series is five items and then it is over.** Before this, the round was
  /// handed the whole pack with no ending and wrapped modulo its item list, so
  /// it played forever — which is an exercise rather than a game.
  /// `ARCHITECTURE.md` §9's definition of the first playable build is *"five
  /// items played on a plane"*, and "played" needs an end.
  ///
  /// Which five is `seriesPlan`'s decision, made without a screen.
  Future<void> _startSeries(BuildContext context, Pack pack) async {
    final int served = await widget.seriesCursor.read();
    if (!context.mounted) {
      return;
    }
    final List<Item> plan = seriesPlan(pack.items, from: served);
    if (plan.isEmpty) {
      // `Pack.fromJson` refuses an empty pack, so this is unreachable through
      // the shipped one — but `RoundScreen` asserts a non-empty list and a
      // caller has to be able to see that coming.
      return;
    }

    // **One id per sitting**, minted before the push so every answer in this
    // series carries the same one. `GET /me/history` groups by it, and a
    // history of one-item sessions is a history nobody can read.
    final String sessionId = _sync.newSessionId();

    await _openSession<void>(
      context,
      (BuildContext sessionContext) => _SeriesSession(
        items: plan,
        fallbackDiagnosis: pack.fallbackDiagnosis,
        now: widget.now,
        attemptDays: _log.days,
        dayLog: _dayLog,
        // Advanced when the series is *finished*, not when it is started:
        // a player who closes a series halfway has not been served those
        // items in any sense worth remembering.
        onFinishedSeries: (int played) => widget.seriesCursor.advance(played),
        onAnswered: (Item item, String answer, Duration elapsed) => unawaited(
          _sync.record(
            itemId: item.id,
            sessionId: sessionId,
            answer: answer,
            at: widget.now(),
            elapsed: elapsed,
          ),
        ),
        // **`onGraded` and never `onAnswered`.** That one carries what the
        // server needs and deliberately no verdict; reading a verdict off it
        // would mean calling `gradeItem` a second time, which is a second
        // decision about one answer — the defect `diagnose` was fixed for.
        onGraded: (Verdict verdict, Duration elapsed) => unawaited(
          _answerRecord.record(
            AnsweredItem(verdict: verdict, elapsed: elapsed),
          ),
        ),
        onDone: () => Navigator.of(sessionContext).maybePop(),
      ),
    );
    // **On the way back, finished or abandoned.** Every answer the series
    // produced is in the journal by now, and the only other flushes are the
    // launch and a session arriving — so a player who played and closed the app
    // left the batch on disk until next time, with `HISTORIAL` empty right
    // after playing. Coming back from a series is exactly the reason to believe
    // there is a network worth trying: it is where `record` last ran.
    //
    // Never awaited, for the reason `record` never touches a socket at all: a
    // player must not wait on one. Failure stays the journal's business —
    // `journalAfter` decides what survives which answer.
    unawaited(_flush());
    // The series may have recorded today. Re-read rather than assume: the store
    // is the source of truth and the screen holds only what it last read.
    await _refreshLog();
  }
}

/// The home's shape, before its data arrives.
///
/// Skeletons and not a spinner: `4.11` is annotated *esqueletos, sin ruedita*.
/// The boxes match what loads, so nothing jumps when it does.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Align(
            alignment: Alignment.centerRight,
            child: SkeletonBlock(width: 64, height: 48, radius: 24),
          ),
          const Spacer(),
          const Center(child: SkeletonBlock(width: 150, height: 150)),
          const SizedBox(height: BrandShape.space5),
          const SkeletonBlock(width: double.infinity, height: 132),
          const Spacer(),
          const SkeletonBlock(width: double.infinity, height: 52, radius: 20),
        ],
      ),
    );
  }
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(BrandShape.space6),
      child: Text(text, textAlign: TextAlign.center, style: BrandText.body()),
    ),
  );
}

/// The round, then its summary.
///
/// A tiny stateful holder rather than a second route: the summary needs the
/// round's outcome, and pushing it would put a screen behind it that a player
/// must never return to — the same reasoning that made the first run a swap
/// rather than a push.
class _SeriesSession extends StatefulWidget {
  const _SeriesSession({
    required this.items,
    required this.fallbackDiagnosis,
    required this.now,
    required this.attemptDays,
    required this.dayLog,
    required this.onFinishedSeries,
    required this.onAnswered,
    required this.onGraded,
    required this.onDone,
  });

  final List<Item> items;

  /// The pack's, threaded through so `RoundScreen` never reaches for one.
  final Diagnosis? fallbackDiagnosis;

  final DateTime Function() now;
  final List<DateTime> attemptDays;
  final DayLogStore dayLog;
  final void Function(int itemsPlayed) onFinishedSeries;

  /// Every answer, the moment it is submitted. Threaded straight through to
  /// `RoundScreen`, because this holder decides nothing about it.
  final void Function(Item item, String answer, Duration elapsed) onAnswered;

  /// The verdict this device decided, threaded straight through for the same
  /// reason [onAnswered] is: this holder decides nothing about it.
  final void Function(Verdict verdict, Duration elapsed) onGraded;

  final VoidCallback onDone;

  @override
  State<_SeriesSession> createState() => _SeriesSessionState();
}

class _SeriesSessionState extends State<_SeriesSession> {
  RoundOutcome? _outcome;

  @override
  Widget build(BuildContext context) {
    final RoundOutcome? outcome = _outcome;
    if (outcome != null) {
      return SeriesSummaryScreen(
        result: SeriesResult(
          correct: outcome.correct,
          total: outcome.total,
          elapsed: outcome.elapsed,
          streakDays: streakLength(
            attemptDays: <DateTime>[...widget.attemptDays, widget.now()],
            today: widget.now(),
          ),
          // **Passed on rather than re-derived.** The round graded every item
          // and is the only thing that can say which one was missed; a count
          // cannot draw the ring, and `SeriesResult` defaults both to nothing,
          // so omitting them here is a summary that renders and says less than
          // it knows.
          outcomes: outcome.outcomes,
          stumble: outcome.stumble,
          stumbleIndex: outcome.stumbleIndex,
        ),
        onDone: widget.onDone,
      );
    }

    return RoundScreen(
      items: widget.items,
      fallbackDiagnosis: widget.fallbackDiagnosis,
      now: widget.now,
      attemptDays: widget.attemptDays,
      dayLog: widget.dayLog,
      onAnswered: widget.onAnswered,
      onGraded: widget.onGraded,
      onFinished: (RoundOutcome result) {
        widget.onFinishedSeries(result.total);
        setState(() => _outcome = result);
      },
    );
  }
}
