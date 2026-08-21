import 'package:flutter/widgets.dart';

import '../../../design/brand/aki.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';

/// `0.4 Calibración intro` — what the probe is, before it starts.
///
/// **Never the word *prueba*.** The design says so in its own label, and the
/// reason is the product rather than the wording: a player who reads this as a
/// test performs, and a probe measures nothing useful once it is performed at.
/// The two pills carry the promise the rest of the flow has to keep — nothing
/// is graded, and it can be left — so both controls the design draws are here
/// and neither is a dead end.
///
/// **Aki belongs here.** She is absent from `0.5` for the same rule that puts
/// her on this screen: nobody is solving yet.
class CalibrationIntroScreen extends StatelessWidget {
  const CalibrationIntroScreen({
    super.key,
    required this.onStart,
    required this.onSkip,
  });

  /// Begins the probe.
  final VoidCallback onStart;

  /// Leaves it, with nothing answered.
  ///
  /// **Skipping is a promise this screen makes**, in the second pill. A pill
  /// that says *"Se puede saltar"* over a screen with no way out is worse than
  /// no pill.
  final VoidCallback onSkip;

  /// Smaller than `0.2`'s 200 and than the design's 222: this screen carries
  /// two lines of display type, three lines of body, two chips and two buttons
  /// under her, and she is the part that can give way. Measured: at 160 the
  /// overflow gate reported *"A RenderFlex overflowed by 5.8 pixels"* on the
  /// notched phone at `textScaler` 1.3, which is the tightest of the four
  /// viewports and the one no design document draws.
  static const double _akiWidth = 138;

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
          Center(child: Aki(width: _akiWidth, semanticLabel: 'Aki')),
          const SizedBox(height: BrandShape.space5),
          _title(),
          const SizedBox(height: BrandShape.space4),
          _promise(),
          const SizedBox(height: BrandShape.space4),
          _pills(),
          const Spacer(),
          BrandButton.primary(label: 'Va, empecemos', onPressed: onStart),
          const SizedBox(height: BrandShape.space3),
          BrandButton.secondary(label: 'Saltar por ahora', onPressed: onSkip),
        ],
      ),
    );
  }

  /// The headline, in the design's two lines.
  ///
  /// `scaleDown` rather than a smaller size: at `textScaler` 1.3 on a notched
  /// phone the two lines are the widest thing on the screen, and shrinking the
  /// display face is what the rest of the app does with a numeral that will not
  /// fit.
  Widget _title() => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'UNOS RÁPIDOS PARA\nACOMODAR TU NIVEL',
          textAlign: TextAlign.center,
          style: BrandText.sectionTitle(size: 38),
        ),
      );

  Widget _promise() => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            'Diez como máximo. Sirven para que los retos lleguen a tu medida, '
            'nada más.',
            textAlign: TextAlign.center,
            style: BrandText.body(),
          ),
        ),
      );

  /// The two promises, as the design's chips.
  Widget _pills() => Wrap(
        alignment: WrapAlignment.center,
        spacing: BrandShape.space2,
        runSpacing: BrandShape.space2,
        children: <Widget>[
          for (final String promise in <String>[
            'No se califica',
            'Se puede saltar',
          ])
            CandySurface.pill(
              // Ink rather than the eyebrow's muted default: the design sets
              // these two in the same weight as the body they qualify.
              child: Text(
                promise,
                style: BrandText.eyebrow(color: BrandColors.ink),
              ),
            ),
        ],
      );
}
