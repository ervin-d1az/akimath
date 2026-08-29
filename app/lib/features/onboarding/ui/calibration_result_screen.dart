import 'package:flutter/widgets.dart';

import '../../../demo/demo_figures.dart';
import '../../../design/brand/aki.dart';
import '../../../design/math/spec/es_mx_number.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/stat_tile.dart';
import '../policy/calibration.dart';

/// `Calibración resultado` — where the probe leaves you.
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
          // **The readable half scrolls; the button does not.** This screen
          // stacks a drawing, a display line, three cards and a paragraph, and
          // it cleared the 390×844 overflow gate at `textScaler` 1.3 by about
          // four percent — measured: it overflowed at 1.35 on macOS and at 1.30
          // on CI's Ubuntu, whose glyph advances are wider. A layout that fits
          // by a pixel on one toolchain does not fit on another, and the runner
          // is the authority. Scrolling removes the ceiling instead of moving
          // it: nothing scrolls while it fits, and there is no arrangement of
          // fonts or text sizes that can overflow it.
          //
          // Keeping the button *outside* the scroll view is the other half.
          // An overflowing `Column` squeezes its children, which is how a 62px
          // control measures under 48 on the rendered screen and takes the
          // touch-target gate with it.
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) =>
                  SingleChildScrollView(
                child: ConstrainedBox(
                  // Centred while it fits, scrolled once it does not — rather
                  // than pinned to the top with a gap under it at 1.0.
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
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
                        // `scaleDown` because the card is a row of a label and
                        // a four-digit numeral, and a wide figure in a fixed
                        // row is what overflowed `4.1`'s tiles sideways.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _ratingCard(),
                        ),
                      ],
                      const SizedBox(height: BrandShape.space4),
                      _measured(),
                      const SizedBox(height: BrandShape.space4),
                      Text(
                        'No es calificación. Es de dónde salimos, y se mueve '
                        'todos los días.',
                        textAlign: TextAlign.center,
                        style: BrandText.body(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: BrandShape.space4),
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
                // **`scaleDown`, because a tile is half a screen wide.**
                // `10 / 10` and an hour-long `64:09` are the widest figures
                // these two can hold, and a numeral that does not fit wraps —
                // which grows the row and overflows the screen rather than the
                // tile. The same shape that overflowed `4.1`'s tile row.
                value: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StatValue(
                    EsMxNumber.ratio(outcome.correct, outcome.answered),
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: BrandShape.space2),
            Expanded(
              child: StatTile(
                label: 'TIEMPO',
                value: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StatValue(
                    EsMxNumber.elapsed(outcome.elapsed),
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
