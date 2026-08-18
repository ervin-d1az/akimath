import 'package:flutter/widgets.dart';

import '../../../content/model/item.dart';
import '../../../design/brand/aki.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/speech_bubble.dart';
import 'bands/family_row.dart';
import 'bands/week_strip.dart';
import '../../round/ui/stimulus/stimulus_view.dart';

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
    this.weekMarks = const <bool>[false, false, false, false, false, false, false],
    this.todaysFamilies = const <String>[],
  });

  /// The item whose expression the card previews.
  final Item preview;

  /// From `StreakPolicy` — a local fact, never the server's.
  final int streakDays;

  final VoidCallback onStart;

  /// Seven days, oldest first, ending today — from `weekMarks`.
  final List<bool> weekMarks;

  /// The families the next series will draw — from `seriesFamilies` over the
  /// same plan that will serve them.
  final List<String> todaysFamilies;

  /// Aki's band on the home is 150, against the verdict screens' 182.
  static const double _akiWidth = 150;

  @override
  Widget build(BuildContext context) {
    // **It scrolls** (design D2). Two bands, Aki, the card and the button do
    // not fit 844 px at `textScaler` 1.3, and shrinking them until they do
    // would be making the screen worse for exactly the readers who chose large
    // text. The order puts the button above the fold at 1.0, so nobody has to
    // scroll to start.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WeekStrip(marks: weekMarks, streakDays: streakDays),
          const SizedBox(height: BrandShape.space4),
          _band(),
          const SizedBox(height: BrandShape.space4),
          _challengeCard(),
          const SizedBox(height: BrandShape.space4),
          if (todaysFamilies.isNotEmpty) ...<Widget>[
            FamilyRow(families: todaysFamilies),
            const SizedBox(height: BrandShape.space4),
          ],
          // Last, so nothing sits below the thing the screen is asking for.
          BrandButton.primary(label: 'Empezar la serie', onPressed: onStart),
          const SizedBox(height: BrandShape.space3),
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
        vertical: BrandShape.space3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('RETO DEL DÍA', style: BrandText.eyebrow()),
          const SizedBox(height: BrandShape.space3),
          // **The same renderer the round uses**, not a picture of one, so the
          // preview cannot drift from the item it shows — and so a day whose
          // first item is a series draws a series instead of throwing. It used
          // to call `nodeFor` directly, which throws on anything that is not an
          // expression.
          // Capped, because the compositor sizes an expression to fill what it
          // is given and a fraction is two lines tall — uncapped it made the
          // card half the screen and pushed everything else into a scroll
          // nobody should need on a phone at ordinary text size.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 116),
            child: StimulusView(stimulus: preview.stimulus),
          ),
        ],
      ),
    );
  }
}
