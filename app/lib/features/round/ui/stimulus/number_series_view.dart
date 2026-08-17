import 'package:flutter/widgets.dart';

import '../../../../design/math/spec/es_mx_number.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../design/widgets/spec/term_visual.dart';
import '../../../../design/widgets/candy_surface.dart';

/// `2 · ? · 18 · 54` — the number-series stimulus.
///
/// The second item family the app can draw, and the first that is not an
/// expression. Everything about it is a row of tiles: the terms the player is
/// given, and the one they have to supply.
///
/// **The hole is a position, not the end.** The payload carries every term —
/// including the true value of the hidden one, which offline grading and the
/// error screen's replay both need on the device — and names the index that is
/// blank. So this widget's first responsibility is a negative one: it must not
/// draw `terms[unknownIndex]`.
///
/// **The unknown tile is yellow and dashed, and that is not decoration.**
/// Solid-and-white means "this is given"; dashed-and-yellow means "this is the
/// hole". The pair has to read as different without relying on hue, because
/// deuteranopia collapses a good deal of the palette — so the outline pattern
/// carries the distinction and the fill only reinforces it. It is the same rule
/// the verdict ring already follows.
class NumberSeriesView extends StatelessWidget {
  const NumberSeriesView({
    super.key,
    required this.terms,
    required this.unknownIndex,
    this.size = 46,
  });

  /// Every term in order, including the hidden one's true value.
  ///
  /// Integers, and written out here rather than in the content: `EsMxNumber`
  /// is what knows that a thousand is `1 000` in es-MX, and a term arriving
  /// pre-formatted would be a rendering decision made by whoever authored the
  /// pack.
  final List<int> terms;

  /// Which term is blank. The value at this index is never rendered.
  final int unknownIndex;

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
      for (int i = 0; i < terms.length; i++)
        if (i == unknownIndex)
          _TermTile(term: '?', size: size, state: TermState.unknown)
        else
          _TermTile(
            term: EsMxNumber.integer(terms[i]),
            size: size,
            state: TermState.given,
          ),
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
