import 'package:flutter/widgets.dart';

import '../icons/brand_icon.dart';
import '../tokens/tokens.dart';
import 'candy_surface.dart';

/// The run, said out loud: a flame, a number and what it counts.
///
/// `Racha en riesgo` draws it above the headline, and it is the reason the
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
            // **The unit gives way, and nothing else does.** At textScaler 1.3
            // the row wants more than `4.12` has to give it — measured at 39 px
            // over on the design phone — and a `Row` at `mainAxisSize.min`
            // has no way to say so except by overflowing. The flame is a fixed
            // glyph and the figure is what the screen is about, so the phrase
            // is the only part that can wrap, and `Flexible` is what lets it.
            //
            // Wrapped, never ellipsised and never scaled down: `días en…`
            // loses the sentence, and shrinking the type spends exactly the
            // size the reader asked for. `offline_screen.dart`'s pill is the
            // same `CandySurface` + `Row` + `BrandIcon` + `Text` composition
            // and already resolves it this way.
            //
            // Inert at 1.0 — a loose `Flexible` changes nothing while the
            // child fits, which is what keeps the drawn instance the drawn
            // instance. `streak_badge_test.dart` holds both halves.
            Flexible(child: Text(_unit, style: BrandText.action(size: 14))),
          ],
        ),
      ),
    );
  }
}
