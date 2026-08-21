import 'package:flutter/widgets.dart';

import '../../../design/icons/brand_icon.dart';
import '../../../design/math/spec/es_mx_number.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/centered_state_view.dart';
import '../../../design/widgets/pressable_surface.dart';
import '../policy/mastery_copy.dart';
import '../policy/topic_suggestion.dart';

/// `4.15 Se acabó el tema por hoy` — today's items for one skill are spent.
///
/// **Nothing routes to this screen.** Running out needs a per-skill daily
/// allowance, and there is none: a series is five items taken in pack order by
/// `seriesPlan`, and the pack does not run out per topic. The rows it offers
/// are half real — `puzzleOfDay` exists and a board is reachable from the home
/// — and the topic half is not, because topics do not exist. It is built and
/// registered rather than wired.
///
/// **Aki is here.** Running out of today's work is not a failure and not an
/// error; she belongs on it the way she belongs on the streak states.
class TopicExhaustedScreen extends StatelessWidget {
  const TopicExhaustedScreen({
    super.key,
    required this.skillName,
    required this.nextTopic,
    required this.puzzleSubtitle,
    required this.onOpenTopic,
    required this.onOpenPuzzle,
    required this.onSwitch,
  });

  /// The skill that ran out, as a player reads it.
  final String skillName;

  /// Where to go instead.
  final NextTopic nextTopic;

  /// The board on offer today: `KenKen · 15 min, sin prisa`. Composed by the
  /// caller, which is the half that knows which board it is.
  final String puzzleSubtitle;

  final VoidCallback onOpenTopic;
  final VoidCallback onOpenPuzzle;

  /// The primary: straight into [nextTopic].
  final VoidCallback onSwitch;

  static const double _leading = 44;

  @override
  Widget build(BuildContext context) {
    return CenteredStateView(
      aki: true,
      headlineLines: <String>[
        'YA NO ME QUEDAN',
        '${skillName.toUpperCase()} HOY',
      ],
      body: 'Mañana hay más, y llegan un poco más difíciles. '
          'Mientras, puedes moverte de tema.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _row(
            leading: _percentTile(nextTopic.percent),
            title: nextTopic.name,
            subtitle: readyChallenges(nextTopic.readyCount),
            onPressed: onOpenTopic,
          ),
          const SizedBox(height: BrandShape.space2),
          _row(
            leading: _puzzleTile(),
            title: 'Puzzle del día',
            subtitle: puzzleSubtitle,
            onPressed: onOpenPuzzle,
          ),
        ],
      ),
      primary: BrandButton.primary(
        label: 'Cambiar a ${nextTopic.name.toLowerCase()}',
        onPressed: onSwitch,
      ),
    );
  }

  /// One destination.
  ///
  /// **The whole row is the target, not the chevron.** A 20px mark is under
  /// the 48px floor (BRD-2d) and is the wrong thing to ask a thumb for anyway
  /// — the card is what a player aims at.
  Widget _row({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) => PressableSurface(
    onPressed: onPressed,
    shadow: BrandShape.shadowTile,
    borderRadius: BrandShape.radiusButton,
    padding: const EdgeInsets.all(BrandShape.space3),
    minHeight: BrandShape.minTouchTarget,
    child: Row(
      children: <Widget>[
        leading,
        const SizedBox(width: BrandShape.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: BrandText.cardTitle(size: 15)),
              Text(subtitle, style: BrandText.caption(size: 12)),
            ],
          ),
        ),
        const SizedBox(width: BrandShape.space2),
        const BrandIcon(BrandGlyph.forward, size: 20),
      ],
    ),
  );

  /// How far into the topic the player already is.
  Widget _percentTile(int percent) => CandySurface(
    width: _leading,
    height: _leading,
    background: BrandColorRole.highlight.color,
    borderRadius: BrandShape.radiusChip,
    borderWidth: BrandShape.borderWidthSmallSurface,
    shadowOffset: Offset.zero,
    alignment: Alignment.center,
    child: Text(EsMxNumber.percent(percent), style: BrandText.numeral(15)),
  );

  /// The board, as a board.
  Widget _puzzleTile() => CandySurface(
    width: _leading,
    height: _leading,
    background: BrandColorRole.canvas.color,
    borderRadius: BrandShape.radiusChip,
    borderWidth: BrandShape.borderWidthSmallSurface,
    shadowOffset: Offset.zero,
    alignment: Alignment.center,
    child: const _BoardMark(),
  );
}

/// A board, as four cells.
///
/// **Composed rather than added to the glyph set.** `icon_paths.dart` holds
/// the sixteen marks transcribed from the icon sheet; this one is drawn inline
/// on `4.15` alone, and a one-off from a screen's artwork does not belong in
/// the set every screen shares — the same call `_ServerTile` makes on `4.10`.
class _BoardMark extends StatelessWidget {
  const _BoardMark();

  static const double _cell = 7;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (int row = 0; row < 2; row++) ...<Widget>[
        if (row > 0) const SizedBox(height: BrandShape.space1 / 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int column = 0; column < 2; column++) ...<Widget>[
              if (column > 0) const SizedBox(width: BrandShape.space1 / 2),
              Container(
                width: _cell,
                height: _cell,
                color: BrandColors.ink,
              ),
            ],
          ],
        ),
      ],
    ],
  );
}
