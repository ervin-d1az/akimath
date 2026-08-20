import 'package:flutter/widgets.dart';

import '../../../design/math/spec/es_mx_number.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/centered_state_view.dart';
import '../../../design/widgets/streak_badge.dart';

/// `4.12 Racha en riesgo` — late in the day with nothing solved.
///
/// **Yellow, never coral.** A streak about to lapse is nobody's mistake, and
/// the declared rules are explicit that coral is error and that losing ground
/// is not one. The badge is the thing being protected, drawn as the thing being
/// protected.
///
/// **The countdown does not break "no visible timer."** That rule is already
/// scoped in code and not only in prose: `quiet_while_you_solve_test.dart`
/// holds it over the solving surfaces — the round, `0.3` and the five boards —
/// and the verdict screens have printed elapsed seconds since F2. A runway on a
/// screen you reach *instead of* solving is the opposite of a clock watching
/// you work.
///
/// **It does not tick, either.** A live countdown needs a timer on a screen
/// whose whole purpose is to send you somewhere else, and a minute's staleness
/// on a three-hour figure is not a lie. Written down because "make it tick" is
/// the obvious next request.
class StreakAtRiskScreen extends StatelessWidget {
  const StreakAtRiskScreen({
    super.key,
    required this.days,
    required this.left,
    required this.onSolve,
    required this.onLater,
  });

  /// The run at stake.
  final int days;

  /// What is left of the local day.
  final Duration left;

  /// Into a challenge. Solving one records the day, which is what makes the
  /// state steady on the next read — the action and the remedy are the same
  /// act.
  final VoidCallback onSolve;

  /// Out to the home, with nothing recorded. The day is still at risk, because
  /// nothing about it changed.
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return CenteredStateView(
      aki: true,
      kicker: StreakBadge(days: days),
      headlineLines: const <String>['HOY TODAVÍA NO', 'RESUELVES NADA'],
      body: 'Con un reto de cuatro minutos queda cerrado el día.',
      content: Center(child: _runway()),
      primary: BrandButton.primary(
        label: 'Resolver uno ahora',
        onPressed: onSolve,
      ),
      // **Not `Recuérdame a las 21:00`.** The design offers it, and it needs a
      // local notification: there is no notification plugin in `pubspec.yaml`,
      // and any candidate has to clear CLAUDE.md's no-phone-home rule before it
      // is a candidate at all. A button that cannot do what it says is worse
      // than an honest one (DR-P2). This is a real way out, which is what the
      // second slot is for.
      secondary: BrandButton.secondary(label: 'Ahora no', onPressed: onLater),
    );
  }

  /// The time left, in a chip that is annotation rather than surface.
  ///
  /// Composed from `CandySurface` rather than extracted: `4.10` wants the same
  /// chip and `4.10` is not built. A widget with one caller is a name nobody
  /// needs yet, and the second caller is where the shape gets settled.
  Widget _runway() {
    return CandySurface(
      borderWidth: BrandShape.borderWidthSmallSurface,
      borderRadius: BrandShape.radiusChip,
      shadowOffset: Offset.zero,
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space2,
      ),
      alignment: Alignment.center,
      child: Text(
        'TE QUEDAN ${EsMxNumber.hoursAndMinutes(left).toUpperCase()}',
        style: BrandText.eyebrow(size: 12, letterSpacing: 0.06),
      ),
    );
  }
}
