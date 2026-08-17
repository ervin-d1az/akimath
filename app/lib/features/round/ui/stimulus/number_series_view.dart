import 'package:flutter/widgets.dart';

import '../../../../design/tokens/tokens.dart';
import '../../../../design/widgets/spec/term_visual.dart';
import '../../../../design/widgets/candy_surface.dart';

/// `2 · 4 · 6 · 8 · ?` — the number-series stimulus.
///
/// The second item family the app can draw, and the first that is not an
/// expression. Everything about it is a row of tiles: the terms the player is
/// given, then the one they have to supply.
///
/// **The unknown tile is yellow and dashed, and that is not decoration.**
/// Solid-and-white means "this is given"; dashed-and-yellow means "this is the
/// hole". The pair has to read as different without relying on hue, because
/// deuteranopia collapses a good deal of the palette — so the outline pattern
/// carries the distinction and the fill only reinforces it. It is the same rule
/// the verdict ring already follows.
class NumberSeriesView extends StatelessWidget {
  const NumberSeriesView({super.key, required this.terms, this.size = 46});

  /// The terms shown, in order. The answer is deliberately **not** among them —
  /// the blank is drawn here, so a pack cannot ship the answer on screen.
  final List<String> terms;

  /// Nominal numeral size, before text scaling.
  final double size;

  @override
  Widget build(BuildContext context) {
    // **One row, and the caller scales it.** `RoundScreen` draws every prompt
    // inside a `FittedBox(scaleDown)`, which is what lets a long arithmetic
    // expression shrink instead of clipping; a series is the same problem with
    // more tiles. Wrapping onto a second line was the first attempt and it
    // looked like two series rather than one.
    final List<Widget> tiles = <Widget>[
      for (final String term in terms)
        _TermTile(term: term, size: size, state: TermState.given),
      _TermTile(term: '?', size: size, state: TermState.unknown),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < tiles.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: BrandShape.space2),
          tiles[i],
        ],
      ],
    );
  }
}

/// One term, given or missing.
class _TermTile extends StatelessWidget {
  const _TermTile({
    required this.term,
    required this.size,
    required this.state,
  });

  final String term;
  final double size;
  final TermState state;

  @override
  Widget build(BuildContext context) {
    // Resolved once, in `resolveTermVisual`. Choosing the hue here with a
    // conditional is what `no_hue_by_comparison_test` fails the build for, and
    // it caught exactly that on the first run of this widget.
    final TermVisual visual = resolveTermVisual(state);

    return CandySurface(
      background: visual.background,
      borderRadius: BrandShape.radiusChip,
      borderWidth: BrandShape.borderWidth,
      shadowOffset: BrandShape.shadowPill,
      // Dashed only on the hole, so the difference survives with the hue gone.
      borderDash: visual.dash,
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space3,
        vertical: BrandShape.space2,
      ),
      // A minimum so a one-digit term and a three-digit term make a row that
      // reads as a series rather than as tiles of assorted widths.
      child: SizedBox(
        width: size,
        child: Center(
          child: Text(
            term,
            maxLines: 1,
            style: BrandText.numeral(size * 0.7),
          ),
        ),
      ),
    );
  }
}
