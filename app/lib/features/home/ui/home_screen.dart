import 'package:flutter/widgets.dart';

import '../../../content/model/item.dart';
import '../../../design/brand/aki.dart';
import '../../../design/math/math_view.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/speech_bubble.dart';
import '../../../design/widgets/stat_pill.dart';
import '../../round/policy/prompt_layout.dart';

/// `Inicio actualizado`, reduced to what F2 can source.
///
/// **The subtractions each have a return phase, and none is a cut** (D5):
/// the rating pill comes back at **F3**, because the rating is the server's
/// exclusive authority and no server exists (Q3, D17); the `PUZZLE DEL DÍA`
/// card at **F6**; the bottom nav at **F5**, when a second root exists.
///
/// **The streak pill is not a subtraction** — it ships here and is the only
/// pill on the F2 home, because a streak is a *local calendar fact* computed on
/// device (D17). It was once listed among the deferrals with a return phase of
/// "F2", which is this change: the two statements were the same statement
/// written as though they disagreed.
///
/// The `TUS HABILIDADES` row is **not** deferred either. It is the structural
/// difference between the two home documents, and choosing `Inicio actualizado`
/// means dropping it.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.preview,
    required this.streakDays,
    required this.onStart,
  });

  /// The item whose expression the card previews.
  final Item preview;

  /// From `StreakPolicy` — a local fact, never the server's.
  final int streakDays;

  final VoidCallback onStart;

  /// Aki's band on the home is 150, against the verdict screens' 182.
  static const double _akiWidth = 150;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: StatPill(
              child: Text('$streakDays', style: BrandText.numeral(22)),
            ),
          ),
          const Spacer(),
          _band(),
          const SizedBox(height: BrandShape.space5),
          _challengeCard(),
          const Spacer(),
          BrandButton.primary(
            label: 'Empezar la serie',
            onPressed: onStart,
          ),
        ],
      ),
    );
  }

  Widget _band() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Aki(width: _akiWidth, semanticLabel: 'Aki'),
        const SizedBox(width: BrandShape.space2),
        const Flexible(
          child: SpeechBubble(text: '¿Le entramos a los retos de hoy?'),
        ),
      ],
    );
  }

  /// `RETO DEL DÍA`, with the expression composed rather than described.
  Widget _challengeCard() {
    return CandySurface(
      borderRadius: BrandShape.radiusCardMedium,
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('RETO DEL DÍA', style: BrandText.eyebrow()),
          const SizedBox(height: BrandShape.space3),
          // The real compositor, not a picture of one: the preview is the same
          // widget the round draws, so it cannot drift from the item it shows.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: MathView(node: nodeFor(preview), size: 46),
          ),
        ],
      ),
    );
  }
}
