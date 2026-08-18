import 'package:flutter/widgets.dart';

import '../../shell/ui/app_shell.dart';
import 'first_item_screen.dart';
import 'welcome_screen.dart';

/// `0.2 → 0.3`, and nothing else.
///
/// **The drawn path is longer and F2 ships two screens of it on purpose** (D11):
/// `0.2 → 0.3 → 0.4 → 0.5 ×10 → 0.6 → mapa` crosses calibration at `0.4` and the
/// map at `0.6`, and neither exists. Shipping `0.4` too would have it promise
/// *"unos rápidos para acomodar tu nivel"* — a promise this build cannot keep,
/// because nothing in it adapts to a level.
///
/// **A swap, not a push.** The teaching item replaces the welcome rather than
/// covering it, because there is nothing behind it a player should return to
/// *after* answering. Pushed, Android's hardware back would land a finished
/// player on the welcome screen again; swapped, back at the root does what back
/// at the root does. The close control is what returns to the welcome, and
/// [PopScope] gives the system gesture the same meaning so the two cannot
/// disagree.
///
/// It holds no store. Whether the first run has happened is one fact with one
/// owner — `FirstRunGate` — and this widget only reports that it is over.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onComplete});

  /// Called once the teaching item has been answered. The caller records the
  /// flag and shows the home.
  final VoidCallback onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  bool _solving = false;

  void _back() => setState(() => _solving = false);

  @override
  Widget build(BuildContext context) {
    if (_solving) {
      return PopScope(
        // The close control and the system gesture do the same thing: back to
        // the welcome. Without this they would differ — one returning, one
        // quitting the app.
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop) {
            _back();
          }
        },
        child: FirstItemScreen(onFinished: widget.onComplete, onBack: _back),
      );
    }

    return AppShell(
      child: WelcomeScreen(onStart: () => setState(() => _solving = true)),
    );
  }
}
