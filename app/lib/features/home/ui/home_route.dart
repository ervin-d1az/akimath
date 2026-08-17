import 'package:flutter/material.dart';

import '../../../content/model/pack.dart';
import '../../../content/pack_reader.dart';
import '../../../design/tokens/tokens.dart';
import '../../round/policy/streak_policy.dart';
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
    this.attemptDays = const <DateTime>[],
  });

  final PackReader reader;
  final DateTime Function() now;

  /// Days already practised. Persistence is `DayLogStore`'s job and does not
  /// exist yet, so today the caller supplies what it knows.
  final List<DateTime> attemptDays;

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> {
  late final Future<Pack> _pack = widget.reader.load();

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
              attemptDays: widget.attemptDays,
              today: widget.now(),
            ),
            onStart: () => _startSeries(context, pack),
          ),
        );
      },
    );
  }

  void _startSeries(BuildContext context, Pack pack) {
    Navigator.of(context).push(
      fullScreenSession<void>(
        (BuildContext context) => RoundScreen(
          items: pack.items,
          now: widget.now,
          attemptDays: widget.attemptDays,
        ),
      ),
    );
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
