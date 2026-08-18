import 'package:flutter/material.dart';

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
import '../policy/series_families.dart';
import '../../round/ui/round_screen.dart';
import '../../round/ui/summary/series_summary_screen.dart';
import '../../shell/ui/app_shell.dart';
import '../../shell/ui/skeleton_block.dart';
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

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> {
  late final Future<Pack> _pack = widget.reader.load();
  late final DayLogStore _dayLog = widget.dayLog ?? const PrefsDayLogStore();
  DayLog _log = DayLog.empty;

  /// How many items have been served, held here as well as read in
  /// `_startSeries`, because the home now *shows* what the next series holds
  /// and cannot await a store while building. Refreshed with the log, so
  /// returning from a series updates both.
  int _itemsServed = 0;

  @override
  void initState() {
    super.initState();
    _refreshLog();
  }

  Future<void> _refreshLog() async {
    final DayLog log = await _dayLog.read();
    final int served = await widget.seriesCursor.read();
    if (mounted) {
      setState(() {
        _log = log;
        _itemsServed = served;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Pack>(
      future: _pack,
      builder: (BuildContext context, AsyncSnapshot<Pack> snapshot) {
        if (snapshot.hasError) {
          return const AppShell(child: _HomeMessage('No se pudo abrir el paquete de retos.'));
        }
        final Pack? pack = snapshot.data;
        if (pack == null) {
          return const AppShell(child: _HomeSkeleton());
        }
        if (pack.isExpiredAt(widget.now().toUtc())) {
          return const AppShell(
            child: _HomeMessage('Estos retos ya vencieron. Conéctate para recibir nuevos.'),
          );
        }

        return AppShell(
          child: HomeScreen(
            preview: pack.items.first,
            streakDays: streakLength(
              attemptDays: _log.days,
              today: widget.now(),
            ),
            weekMarks: weekMarks(
              attemptDays: _log.days,
              today: widget.now(),
            ),
            // **The plan the player is about to be served**, not the pack in
            // general. `_startSeries` calls `seriesPlan` with the same cursor,
            // so the row cannot promise a family the series will not draw.
            todaysFamilies: seriesFamilies(
              seriesPlan(pack.items, from: _itemsServed),
            ),
            onStart: () => _startSeries(context, pack),
          ),
        );
      },
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

    await Navigator.of(context).push(
      fullScreenSession<void>(
        (BuildContext sessionContext) => _SeriesSession(
          items: plan,
          now: widget.now,
          attemptDays: _log.days,
          dayLog: _dayLog,
          // Advanced when the series is *finished*, not when it is started:
          // a player who closes a series halfway has not been served those
          // items in any sense worth remembering.
          onFinishedSeries: (int played) => widget.seriesCursor.advance(played),
          onDone: () => Navigator.of(sessionContext).maybePop(),
        ),
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
    required this.now,
    required this.attemptDays,
    required this.dayLog,
    required this.onFinishedSeries,
    required this.onDone,
  });

  final List<Item> items;
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
