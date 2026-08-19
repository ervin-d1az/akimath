import 'package:flutter/material.dart';

import '../../../api/auth_client.dart';
import '../../../api/endpoints.dart';
import '../../auth/ui/auth_flow.dart';
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
  const PreferencesRoute({
    super.key,
    this.dayLog,
    this.now = DateTime.now,
    this.authBaseUrl = Endpoints.authBaseUrl,
  });

  final DayLogStore? dayLog;

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

  @override
  State<PreferencesRoute> createState() => _PreferencesRouteState();
}

class _PreferencesRouteState extends State<PreferencesRoute> {
  late final DayLogStore _store = widget.dayLog ?? const PrefsDayLogStore();
  DayLog _log = DayLog.empty;

  /// The address of the account this device linked, once it has one.
  ///
  /// **In memory only, and deliberately.** Persisting a session is its own
  /// change with its own decision about where a token may be written; until
  /// then the flow is runnable and the result is visible, which is what the
  /// slice is for.
  String? _accountEmail;

  void _openAccountFlow() {
    final AuthClient auth = AuthClient(baseUrl: Uri.parse(widget.authBaseUrl));
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext _) => AppShell(
        child: AuthFlow(
          auth: auth,
          callbackUrl: Endpoints.callbackUrl,
          today: widget.now(),
          onLinked: (LinkedAccount account) {
            auth.close();
            if (!mounted) {
              return;
            }
            setState(() => _accountEmail = account.email);
            Navigator.of(context).pop();
          },
          onGaveUp: () {
            auth.close();
            Navigator.of(context).pop();
          },
        ),
      ),
    ));
  }

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
        accountEmail: _accountEmail,
        // Absent rather than broken when the build was given no endpoints.
        onCreateAccount: widget.authBaseUrl.isNotEmpty && _accountEmail == null
            ? _openAccountFlow
            : null,
      ),
    );
  }
}
