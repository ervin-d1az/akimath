import 'dart:async';

import 'package:flutter/material.dart';

import '../../../content/model/diagnosis.dart';
import '../../../content/model/item.dart';
import '../../../content/model/pack.dart';
import '../../../content/pack_reader.dart';
import '../../../design/tokens/tokens.dart';
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
import '../../shell/ui/app_shell.dart';
import '../../../content/model/puzzle.dart';
import '../../puzzle/ui/puzzle_screen.dart';
import '../../puzzle/ui/puzzle_solved_screen.dart';
import '../../puzzle/ui/word_search_screen.dart';
import '../../shell/ui/skeleton_block.dart';
import '../../states/data/streak_notice_store.dart';
import '../../states/policy/streak_notice.dart';
import '../../states/ui/streak_at_risk_screen.dart';
import '../../states/ui/streak_lost_screen.dart';
import '../policy/broken_run.dart';
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
  });

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

  /// The launch: read what is stored, then show what it owes.
  ///
  /// **In that order, and only here.** `_refreshLog` runs again on every return
  /// from a series or a board; the notice must not. Deciding it before the log
  /// is read would decide it from an empty one, which is `StreakNotice.none`
  /// for every player.
  Future<void> _open() async {
    await _refreshLog();
    if (!mounted) {
      return;
    }
    await _showNoticeIfDue();
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
    await pushSession<void>(context, (BuildContext noticeContext) {
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
        final Pack? pack = snapshot.data;
        if (pack == null) {
          return const AppShell(child: _HomeSkeleton());
        }
        if (pack.isExpiredAt(widget.now().toUtc())) {
          return const AppShell(
            child: _HomeMessage(
              'Estos retos ya vencieron. Conéctate para recibir nuevos.',
            ),
          );
        }

        return AppShell(
          child: HomeScreen(
            preview: pack.items.first,
            streakDays: streakLength(
              attemptDays: _log.days,
              today: widget.now(),
            ),
            weekMarks: weekMarks(attemptDays: _log.days, today: widget.now()),
            // **The plan the player is about to be served**, not the pack in
            // general. `_startSeries` calls `seriesPlan` with the same cursor,
            // so the row cannot promise a family the series will not draw.
            todaysFamilies: seriesFamilies(
              seriesPlan(pack.items, from: _itemsServed),
            ),
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
  Future<void> _startPuzzle(BuildContext context, Puzzle puzzle) async {
    // **The route holds the clock** (design D3). Neither puzzle screen has one,
    // and adding one to both would be the same decision written twice — the
    // objection that put `onPractised` here rather than a store in each screen.
    //
    // Wall-clock from opening the board, rules-reading included. A puzzle is a
    // sitting, not a reaction test.
    final DateTime startedAt = widget.now();

    await pushSession<void>(context, (BuildContext sessionContext) {
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

    await pushSession<void>(
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
        onDone: () => Navigator.of(sessionContext).maybePop(),
      ),
    );
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
    required this.onDone,
  });

  final List<Item> items;

  /// The pack's, threaded through so `RoundScreen` never reaches for one.
  final Diagnosis? fallbackDiagnosis;

  final DateTime Function() now;
  final List<DateTime> attemptDays;
  final DayLogStore dayLog;
  final void Function(int itemsPlayed) onFinishedSeries;
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
      onFinished: (RoundOutcome result) {
        widget.onFinishedSeries(result.total);
        setState(() => _outcome = result);
      },
    );
  }
}
