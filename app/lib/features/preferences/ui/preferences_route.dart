import 'package:flutter/material.dart';

import '../../home/data/day_log_store.dart';
import '../../home/data/prefs_day_log_store.dart';
import '../../home/policy/day_log.dart';
import '../../round/policy/streak_policy.dart';
import '../../shell/ui/app_shell.dart';
import 'preferences_screen.dart';

/// Reads the day log and hands the screen two numbers.
///
/// The adapter half, and it is small on purpose: everything this root shows is
/// already computed by policies the home uses, so there is nothing here to get
/// wrong except the reading.
class PreferencesRoute extends StatefulWidget {
  const PreferencesRoute({super.key, this.dayLog, this.now = DateTime.now});

  final DayLogStore? dayLog;

  /// Injected, so the streak can be tested by handing it a date.
  final DateTime Function() now;

  @override
  State<PreferencesRoute> createState() => _PreferencesRouteState();
}

class _PreferencesRouteState extends State<PreferencesRoute> {
  late final DayLogStore _store = widget.dayLog ?? const PrefsDayLogStore();
  DayLog _log = DayLog.empty;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final DayLog log = await _store.read();
    if (mounted) {
      setState(() => _log = log);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: PreferencesScreen(
        // Zero before the store answers, and zero for a player who has never
        // played — the same number, which is why nothing here waits on a
        // skeleton. There is no state in which this screen has nothing to say.
        daysPractised: _log.days.length,
        streakDays: streakLength(attemptDays: _log.days, today: widget.now()),
      ),
    );
  }
}
