import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../api/api_client.dart';
import '../../../api/endpoints.dart';
import '../../account/policy/session.dart';
import '../../home/data/day_log_store.dart';
import '../../home/data/prefs_day_log_store.dart';
import '../../home/policy/day_log.dart';
import '../../round/policy/streak_policy.dart';
import '../../shell/ui/app_shell.dart';
import '../policy/progress_view.dart';
import 'progress_screen.dart';

/// Reads the day log, asks the server for the rest, and hands the screen both.
///
/// **The two halves are fetched independently and drawn independently.** The
/// figures come from `shared_preferences` and are always available; the history
/// needs a session and a network. A route that waited for both would hide what
/// the device already knows behind a request that may never answer.
///
/// **The request arrives as a closure**, the same shape `EraseAccountRoute`
/// uses and for the same reason: a `testWidgets` runs in a fake-async zone and
/// a real socket inside one hangs on `!timersPending`.
class ProgressRoute extends StatefulWidget {
  const ProgressRoute({
    super.key,
    this.session,
    this.dayLog,
    this.now = DateTime.now,
    this.fetchHistory,
  });

  /// The account this device is signed in to, if it is.
  final LinkedSession? session;

  final DayLogStore? dayLog;

  /// Injected, so the streak can be tested by handing it a date.
  final DateTime Function() now;

  /// Overridden in tests. In production it opens a socket.
  final Future<HistoryResult> Function(String accessToken)? fetchHistory;

  @override
  State<ProgressRoute> createState() => _ProgressRouteState();
}

class _ProgressRouteState extends State<ProgressRoute> {
  late final DayLogStore _store = widget.dayLog ?? const PrefsDayLogStore();
  DayLog _log = DayLog.empty;
  HistoryResult? _history;

  @override
  void initState() {
    super.initState();
    unawaited(_readDayLog());
    unawaited(_askForHistory());
  }

  @override
  void didUpdateWidget(ProgressRoute old) {
    super.didUpdateWidget(old);
    // The session arrives after the player links, on a screen that is already
    // built — `IndexedStack` keeps both roots alive, so this root is not
    // rebuilt from scratch when the other one signs in.
    if (widget.session?.accessToken != old.session?.accessToken) {
      setState(() => _history = null);
      unawaited(_askForHistory());
    }
  }

  Future<void> _readDayLog() async {
    final DayLog log = await _store.read();
    if (mounted) {
      setState(() => _log = log);
    }
  }

  Future<void> _askForHistory() async {
    final LinkedSession? session = widget.session;
    if (session == null) {
      return;
    }
    final HistoryResult result = await (widget.fetchHistory ?? _overASocket)(
      session.accessToken,
    );
    if (!mounted) {
      return;
    }
    setState(() => _history = result);
  }

  Future<HistoryResult> _overASocket(String accessToken) async {
    final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
    try {
      return await api.getHistory(accessToken);
    } finally {
      api.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    // **`noAccount` before anything else.** With no session there is no request
    // in flight, so `loading` would be a wait for something nobody asked for.
    final HistoryState state = widget.session == null
        ? HistoryState.noAccount
        : historyStateFor(_history);
    final HistoryResult? result = _history;

    return AppShell(
      child: ProgressScreen(
        // Zero before the store answers and zero for a player who has never
        // played — the same number, which is why nothing here waits.
        daysPractised: _log.days.length,
        streakDays: streakLength(attemptDays: _log.days, today: widget.now()),
        historyState: state,
        entries: result is HistoryFound ? result.history.entries : const <HistoryEntry>[],
        onRetryHistory: canRetryHistory(state)
            ? () {
                setState(() => _history = null);
                unawaited(_askForHistory());
              }
            : null,
      ),
    );
  }
}
