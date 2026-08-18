import 'package:flutter/widgets.dart';

import '../../home/ui/home_route.dart';
import '../../shell/ui/app_shell.dart';
import '../data/onboarding_store.dart';
import 'onboarding_flow.dart';

/// Chooses the onboarding or the home, from the flag.
///
/// **The flag has one owner.** The gate reads it, and the gate writes it — the
/// flow that shows the screens does neither, so there is one place to look when
/// asking why a launch went where it went.
///
/// **Neither branch is taken while the answer is unknown.** A preference read is
/// a frame or two, and guessing during it is visible either way: guess *complete*
/// and a first-run player sees the home flash before the welcome; guess
/// *incomplete* and a returning player sees the welcome flash before the home —
/// which is the worse of the two, because it looks like lost progress. So the
/// gate shows the frame it is honest about: cream, empty, and gone.
class FirstRunGate extends StatefulWidget {
  const FirstRunGate({
    super.key,
    this.store = const OnboardingStore(),
    this.home = const HomeRoute(),
  });

  final OnboardingStore store;

  /// What a returning player gets.
  ///
  /// Injected so a test can walk the first run without reaching for the bundled
  /// pack, and so this file does not have to know how the home is assembled.
  final Widget home;

  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  /// `null` until the flag has been read. See the class comment: it is a third
  /// state on purpose, not a missing default.
  bool? _complete;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bool complete = await widget.store.isComplete();
    if (mounted) {
      setState(() => _complete = complete);
    }
  }

  /// Records the completion **before** showing the home.
  ///
  /// Written first so a player who finishes the first run and closes the app
  /// immediately is not shown it again. The store swallows its own failures, in
  /// which case the onboarding repeats — annoying, and strictly better than a
  /// launch that fails.
  Future<void> _finishFirstRun() async {
    await widget.store.markComplete();
    if (mounted) {
      setState(() => _complete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool? complete = _complete;
    if (complete == null) {
      return const AppShell(child: SizedBox.expand());
    }
    return complete
        ? widget.home
        : OnboardingFlow(onComplete: _finishFirstRun);
  }
}
