import 'package:flutter/material.dart';

import '../../../content/model/pack.dart';
import '../../../content/pack_reader.dart';
import '../../../design/tokens/tokens.dart';
import '../../round/policy/streak_policy.dart';
import '../data/day_log_store.dart';
import '../policy/day_log.dart';
import '../../round/ui/round_screen.dart';
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
  });

  final PackReader reader;
  final DateTime Function() now;

  /// Where the days practised are kept.
  ///
  /// Defaults to an in-memory store, which is the honest default while no
  /// persistent one exists: the streak is true within a session and starts over
  /// on relaunch, rather than being a number nothing backs.
  final DayLogStore? dayLog;

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> {
  late final Future<Pack> _pack = widget.reader.load();
  late final DayLogStore _dayLog = widget.dayLog ?? InMemoryDayLogStore();
  DayLog _log = DayLog.empty;

  @override
  void initState() {
    super.initState();
    _refreshLog();
  }

  Future<void> _refreshLog() async {
    final DayLog log = await _dayLog.read();
    if (mounted) {
      setState(() => _log = log);
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
            onStart: () => _startSeries(context, pack),
          ),
        );
      },
    );
  }

  Future<void> _startSeries(BuildContext context, Pack pack) async {
    await Navigator.of(context).push(
      fullScreenSession<void>(
        (BuildContext context) => RoundScreen(
          items: pack.items,
          now: widget.now,
          attemptDays: _log.days,
          dayLog: _dayLog,
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
