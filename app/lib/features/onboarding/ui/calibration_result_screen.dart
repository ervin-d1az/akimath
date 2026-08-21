import 'package:flutter/widgets.dart';

import '../../../demo/demo_figures.dart';
import '../../../design/brand/aki.dart';
import '../../../design/math/spec/es_mx_number.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/stat_tile.dart';
import '../policy/calibration.dart';

/// `0.6 Calibración resultado` — where the probe leaves you.
///
/// **Two of the three things the design draws here do not exist, and the
/// difference is on the screen rather than hidden.**
///
/// - The **count and the time are real**. Every item was graded on the device
///   by the same `gradeItem` the round uses, and the clock was the probe's own.
/// - The **rating is invented** and comes from `DemoFigures`, the one
///   quarantined home for a figure the product cannot compute. There is no
///   rating system — rating is F4, `user_skills` is written by nothing, and
///   `GET /me/standing` answers `skills: []` for every player alive — so
///   nothing here derives it from the count beside it, and deleting the demo
///   figures deletes this card.
/// - The **skill map is absent.** The design draws four nodes, two lit, one at
///   `38%` and one dashed. Every one of those is a placement, a placement needs
///   a placement algorithm, and there is none. A tree drawn from nothing would
///   be the one claim this screen must not make, so the slot carries the
///   figures the probe actually produced instead.
///
/// The design's own sentence — *"No es calificación. Es de dónde salimos"* —
/// is what keeps the count from reading as the grade `0.4` promised it is not,
/// and it sits directly under the figures for that reason.
class CalibrationResultScreen extends StatelessWidget {
  const CalibrationResultScreen({
    super.key,
    required this.outcome,
    required this.onEnter,
  });

  /// What the probe measured. Only drawn when it has something to report —
  /// `OnboardingFlow` skips this screen entirely otherwise.
  final CalibrationOutcome outcome;

  /// Leaves for whatever comes next.
  ///
  /// **The screen does not know where.** The design's label says *mapa* and the
  /// app's root is the home, which is a wiring question and not this widget's.
  final VoidCallback onEnter;

  static const double _akiWidth = 132;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Spacer(),
          Center(
            child: Aki(
              width: _akiWidth,
              pose: AkiPose.correct,
              semanticLabel: 'Aki',
            ),
          ),
          const SizedBox(height: BrandShape.space4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'AQUÍ EMPIEZAS',
              style: BrandText.sectionTitle(size: 44),
            ),
          ),
          if (DemoFigures.enabled) ...<Widget>[
            const SizedBox(height: BrandShape.space4),
            Center(child: _ratingCard()),
          ],
          const SizedBox(height: BrandShape.space4),
          _measured(),
          const SizedBox(height: BrandShape.space4),
          Text(
            'No es calificación. Es de dónde salimos, y se mueve todos los '
            'días.',
            textAlign: TextAlign.center,
            style: BrandText.body(),
          ),
          const Spacer(),
          BrandButton.primary(label: 'Entrar a mi mapa', onPressed: onEnter),
        ],
      ),
    );
  }

  /// The design's rating card, drawn from the quarantine.
  ///
  /// It is a row rather than a tile because the design sets the label beside
  /// the figure here and under it everywhere else.
  Widget _ratingCard() => CandySurface(
        borderRadius: BrandShape.radiusCardSmall,
        shadowOffset: BrandShape.shadowButton,
        padding: const EdgeInsets.symmetric(
          horizontal: BrandShape.space5,
          vertical: BrandShape.space2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text('RATING', style: BrandText.eyebrow(size: 12)),
            const SizedBox(width: BrandShape.space2),
            Text(
              EsMxNumber.integer(DemoFigures.rating),
              style: BrandText.numeral(34),
            ),
          ],
        ),
      );

  /// The two figures the probe actually produced.
  ///
  /// `0.7`'s three-tile idiom from the same document, with two tiles because
  /// there are two true figures — a third would have to be invented, which is
  /// the whole argument of this screen.
  Widget _measured() => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: 'ACIERTOS',
                value: StatValue(
                  EsMxNumber.ratio(outcome.correct, outcome.answered),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: BrandShape.space2),
            Expanded(
              child: StatTile(
                label: 'TIEMPO',
                value: StatValue(
                  EsMxNumber.elapsed(outcome.elapsed),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      );
}
