import 'package:flutter/widgets.dart';

import '../icons/brand_icon.dart';
import '../tokens/tokens.dart';
import 'candy_surface.dart';

/// The run, said out loud: a flame, a number and what it counts.
///
/// `4.12 Racha en riesgo` draws it above the headline, and it is the reason the
/// screen lands — the figure at stake is the first thing on it. Yellow and
/// raised, because it is the thing being protected and not a warning: coral is
/// error, and a streak about to lapse is nobody's mistake.
///
/// A `CandySurface` composition, per the design's own §4.3. There is no new
/// primitive here and there must not be one.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days});

  /// How many consecutive days are in play.
  final int days;

  /// The unit, agreeing with the count.
  ///
  /// **A day-one run is real and reachable** — solve on Monday, come back late
  /// on Tuesday and this badge says `1`. `1 días en juego` is the sentence a
  /// count that never learned to agree prints, and it is the first thing a
  /// reader notices.
  String get _unit => days == 1 ? 'día en juego' : 'días en juego';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$days $_unit',
      excludeSemantics: true,
      child: CandySurface(
        background: BrandColors.yellow,
        borderRadius: BrandShape.radiusCardSmall,
        shadowOffset: BrandShape.shadowButton,
        padding: const EdgeInsets.symmetric(
          horizontal: BrandShape.space4,
          vertical: BrandShape.space2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const BrandIcon(BrandGlyph.flame, size: 20),
            const SizedBox(width: BrandShape.space2),
            Text('$days', style: BrandText.numeral(30)),
            const SizedBox(width: BrandShape.space2),
            Text(_unit, style: BrandText.action(size: 14)),
          ],
        ),
      ),
    );
  }
}
