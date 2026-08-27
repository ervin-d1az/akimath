import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/before_after_counters.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/centered_state_view.dart';
import '../../home/policy/broken_run.dart';

/// `4.13 Racha perdida` — the run reset, and the page turns.
///
/// Annotated *"se pasa la página"*: no consolation, no reproach, one forward
/// action. Aki stays in her calm pose, because there is no sad one and there
/// should not be — she does not scold and does not look disappointed.
///
/// **The `1` is [dayOfNewRun] and not the streak.** This screen is reached
/// before the player has solved, where `streakLength` correctly returns 0. One
/// function answering both questions would be the home and this screen
/// disagreeing about what a streak counts; two quantities cannot drift.
///
/// **No rating appears.** The design reassures with *"Tu rating sigue donde lo
/// dejaste"* over a figure of `1 248`. Rating is F4 and `GET /me/standing`
/// answers 501 — a promise about a number the player has never seen is worse
/// than silence, which is the reading that already keeps a rating off the
/// verdict screens. The sentence says the true half.
///
/// **The left counter is captioned *ANTES*, and the design says *AYER*.** This
/// is a deliberate departure, and the design is the half that is wrong: it
/// draws `AYER 13 → HOY 1`, but `StreakState.broken` requires `streakLength`
/// to be 0, which requires the log to hold neither today *nor yesterday*. The
/// run this screen reports on therefore ended two or more days ago, always —
/// so *AYER* is a false statement shown to a player, on every reachable input
/// rather than on an edge case. *ANTES* makes no claim the log can contradict
/// and keeps the pairing with *HOY* the design intends. `streak_state_test.dart`
/// holds the invariant over a sweep and `streak_screens_test.dart` closes it to
/// this caption, so the day either the policy or the copy moves, one goes red.
/// **Pending the design's own correction** — the source of truth for the screen
/// is the Claude Design project, and it still draws *AYER*.
class StreakLostScreen extends StatelessWidget {
  const StreakLostScreen({
    super.key,
    required this.brokenRun,
    required this.onStart,
  });

  /// How long the run that ended was.
  final int brokenRun;

  /// Into today's challenge — the act that makes [dayOfNewRun] earned.
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return CenteredStateView(
      aki: true,
      headlineLines: const <String>['LA RACHA', 'VOLVIÓ A UNO'],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BeforeAfterCounters(
            before: brokenRun,
            beforeCaption: 'ANTES',
            after: dayOfNewRun,
            afterCaption: 'HOY',
          ),
          const SizedBox(height: BrandShape.space5),
          CandySurface(
            borderRadius: BrandShape.radiusPanel,
            shadowOffset: BrandShape.shadowButton,
            padding: const EdgeInsets.all(BrandShape.space4),
            child: Text(
              'Lo que aprendiste no se reinició. '
              'Solo el conteo vuelve a empezar.',
              style: BrandText.body(),
            ),
          ),
        ],
      ),
      primary: BrandButton.primary(
        label: 'Empezar la de hoy',
        onPressed: onStart,
      ),
    );
  }
}
