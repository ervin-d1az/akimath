import 'package:flutter/widgets.dart';

import '../../home/ui/home_route.dart';
import '../../splash/splash_screen.dart';
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
/// gate shows the frame it is honest about, which is the splash: it says the app
/// is starting and claims nothing about which screen is coming.
class FirstRunGate extends StatefulWidget {
  const FirstRunGate({
    super.key,
    this.store = const OnboardingStore(),
    this.home = const HomeRoute(),
    this.splashFloor = defaultSplashFloor,
  });

  /// How long the splash stays up even when there is nothing left to wait for.
  ///
  /// **A floor, not a delay.** Reading one boolean from `shared_preferences`
  /// takes a few milliseconds, so without this the splash is a flicker between
  /// the system launch image and the first real screen — which reads as a
  /// glitch rather than as a brand. The app is not made slower: the flag is
  /// read *while* this elapses, and a slow read simply outlasts it.
  ///
  /// Injectable because every widget test would otherwise pay it.
  static const Duration defaultSplashFloor = Duration(milliseconds: 1100);

  final Duration splashFloor;

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
    // Both at once, so the floor and the read overlap rather than add up.
    final List<Object?> both = await Future.wait(<Future<Object?>>[
      widget.store.isComplete(),
      Future<void>.delayed(widget.splashFloor),
    ]);
    if (mounted) {
      setState(() => _complete = both.first as bool);
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
      // **The splash, which until now was built and reachable from nowhere.**
      // This is the frame the gate was already honest about — it knows only
      // that it does not yet know — and an empty cream rectangle was the
      // placeholder standing in for a treatment that existed the whole time.
      return const SplashScreen(variant: SplashVariant.brandGreen);
    }
    return complete
        ? widget.home
        : OnboardingFlow(onComplete: _finishFirstRun);
  }
}
