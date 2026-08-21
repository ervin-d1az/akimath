import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../content/model/item.dart';
import '../../../content/model/pack.dart';
import '../../../content/pack_reader.dart';
import '../../home/data/series_cursor_store.dart';
import '../../shell/ui/app_shell.dart';
import '../policy/calibration.dart';
import 'calibration_intro_screen.dart';
import 'calibration_item_screen.dart';
import 'calibration_result_screen.dart';
import 'first_item_screen.dart';
import 'save_progress_screen.dart';
import 'welcome_screen.dart';

/// Which screen of the first run is on.
///
/// **A closed set rather than the `bool` this used to be.** Two screens fitted
/// in a flag; six do not, and a flag that selects between more than two things
/// is the shape FUN-2 exists to prevent.
enum OnboardingStep {
  /// `0.2 Bienvenida`.
  welcome,

  /// `0.3 Primer reto`.
  teachingItem,

  /// `0.4 Calibración intro`.
  calibrationIntro,

  /// `0.5 Calibración reactivo`, repeated for every item in the plan.
  probe,

  /// `0.6 Calibración resultado`. Skipped when there is nothing to report.
  result,

  /// `0.7 Guardar progreso`, the last screen of the run.
  saveProgress,
}

/// `0.2 → 0.3 → 0.4 → 0.5 ×n → 0.6 → 0.7`, and then the home.
///
/// **The whole sequence is the first run, and the flag is set at the end of
/// it.** It used to be set at the solved teaching item, which was correct when
/// `0.3` was the last screen. Four screens now sit after it and the last of
/// them is the only invitation the product ever makes to keep any of this, so a
/// flag set at `0.3` would hide them from a player who closed the app on `0.5`.
/// Leaving the teaching item still sets nothing, for the reason `FirstItemScreen`
/// records: the flag is earned by walking the run, never by escaping it.
///
/// **Two of the six screens are skipped rather than shown empty.** `0.4`–`0.6`
/// need items to ask, so a pack that could not be read steps over all three;
/// and `0.6` needs an answer to report, so a probe skipped outright steps over
/// it. Both are the reading the profile already makes about `HISTORIAL`: a
/// screen with nothing true to say is absent, not present and reading zero.
///
/// **A swap, not a push.** Every screen replaces the last, because there is
/// nothing behind any of them a player should return to. The teaching item
/// keeps its [PopScope] so the close control and the system gesture agree.
///
/// It holds no store. Whether the first run has happened is one fact with one
/// owner — `FirstRunGate` — and this widget only reports that it is over.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onComplete,
    this.onCreateAccount,
    this.reader = const PackReader(),
    this.seriesCursor = const SeriesCursorStore(),
  });

  /// Called once the run is over. The caller records the flag and shows the
  /// home.
  final VoidCallback onComplete;

  /// Called by `0.7`'s green button, when a build has an account flow.
  ///
  /// Null draws no such button — a control that goes nowhere is worse than no
  /// control (DR-P2). The caller is expected to record the flag too: the player
  /// has seen the whole run either way.
  final VoidCallback? onCreateAccount;

  /// Where the probe's items come from.
  ///
  /// Injected, so a test walks the run without reaching for
  /// `assets/packs/starter.json`.
  final PackReader reader;

  /// The cursor the home reads to decide which items it has not served yet.
  ///
  /// **The probe writes to it, because the probe serves items.** It takes the
  /// pack's first ten; the home previews `pack.items.first` as `RETO DEL DÍA`
  /// and opens its first series at `seriesPlan(pack.items, from: 0)`. Without
  /// this the player would meet all ten again on the very next screen, which is
  /// the `7 + 6` defect `FirstItemScreen` records — the teaching item was the
  /// pack's first, so it was solved in the tutorial and met twice more one tap
  /// later.
  final SeriesCursorStore seriesCursor;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  OnboardingStep _step = OnboardingStep.welcome;

  /// The probe, or nothing when the pack could not be read.
  List<Item> _probe = const <Item>[];

  CalibrationOutcome _outcome = CalibrationOutcome.none;

  @override
  void initState() {
    super.initState();
    // Read now rather than when `0.4` is reached: a player crosses two screens
    // first, so the probe is ready long before it is wanted and nothing on the
    // path has to draw a wait. There is no spinner in this app to draw one with.
    _readProbe();
  }

  Future<void> _readProbe() async {
    try {
      final Pack pack = await widget.reader.load();
      if (mounted) {
        setState(() => _probe = calibrationPlan(pack.items));
      }
    } catch (error) {
      // **Deliberately broad, and reported rather than swallowed** — the same
      // rule `OnboardingStore` states: nothing about the stored or bundled
      // content may prevent a launch, and that is wider than the exception
      // hierarchy. The consequence is visible and honest: with no items, the
      // three probe screens are skipped.
      debugPrint('onboarding: could not read the pack for the probe ($error)');
    }
  }

  void _to(OnboardingStep step) => setState(() => _step = step);

  /// The teaching item is behind the player.
  ///
  /// **The probe is skipped whole when there is nothing to ask**, rather than
  /// showing `0.4`'s *"Diez como máximo"* over a probe of none.
  void _afterTeachingItem() => _to(
        _probe.isEmpty
            ? OnboardingStep.saveProgress
            : OnboardingStep.calibrationIntro,
      );

  void _afterProbe(CalibrationOutcome outcome) {
    // **What was answered, not what was planned.** The cursor counts items
    // *served*, so a probe left after four advances by four and the other six
    // are still the player's to meet. Not awaited: the home re-reads the cursor
    // on its own launch, and a write that failed costs a repeat rather than a
    // stuck screen.
    unawaited(widget.seriesCursor.advance(outcome.answered));
    setState(() {
      _outcome = outcome;
      _step = outcome.hasSomethingToReport
          ? OnboardingStep.result
          : OnboardingStep.saveProgress;
    });
  }

  @override
  Widget build(BuildContext context) => switch (_step) {
        OnboardingStep.welcome => AppShell(
            child: WelcomeScreen(
              onStart: () => _to(OnboardingStep.teachingItem),
            ),
          ),
        OnboardingStep.teachingItem => PopScope(
            // The close control and the system gesture do the same thing: back
            // to the welcome. Without this they would differ — one returning,
            // one quitting the app.
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (!didPop) {
                _to(OnboardingStep.welcome);
              }
            },
            child: FirstItemScreen(
              onFinished: _afterTeachingItem,
              onBack: () => _to(OnboardingStep.welcome),
            ),
          ),
        OnboardingStep.calibrationIntro => AppShell(
            child: CalibrationIntroScreen(
              onStart: () => _to(OnboardingStep.probe),
              onSkip: () => _to(OnboardingStep.saveProgress),
            ),
          ),
        // Bare, like the teaching item: it brings its own `Scaffold`.
        OnboardingStep.probe => CalibrationItemScreen(
            items: _probe,
            onFinished: _afterProbe,
          ),
        OnboardingStep.result => AppShell(
            child: CalibrationResultScreen(
              outcome: _outcome,
              onEnter: () => _to(OnboardingStep.saveProgress),
            ),
          ),
        OnboardingStep.saveProgress => AppShell(
            child: SaveProgressScreen(
              // The teaching item plus every probe item answered. Both were
              // graded on the device, so both are challenges this player did.
              challenges: 1 + _outcome.answered,
              // **Zero, and the tile is therefore absent.** Neither the
              // teaching item nor the probe passes a `DayLogStore`, so the home
              // behind this screen will read no days practised — and a tile
              // saying `1 DÍA` would be contradicted one tap later, which is
              // the `RACHA 1` defect in its other direction.
              days: 0,
              onCreateAccount: widget.onCreateAccount,
              onLater: widget.onComplete,
            ),
          ),
      };
}
