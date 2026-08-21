import 'package:flutter/widgets.dart';

import '../../../design/brand/aki.dart';
import '../../../design/icons/brand_icon.dart';
import '../../../design/math/spec/es_mx_number.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/centered_state_view.dart';
import '../policy/mastery_copy.dart';

/// `4.14 Habilidad dominada` — a skill finished, and what it opened.
///
/// **Nothing routes to this screen, and nothing can.** Mastery needs a skill
/// with a completion behind it: `GET /me/standing` answers `skills: []` for
/// every player, because nothing writes `user_skills`. There is no level to
/// rise and no rating to rise with it, so a trigger would have to be invented,
/// and an invented trigger fires on a rule nobody agreed. It is built and
/// registered so the design exists in code; it is wired the day a skill can be
/// completed.
///
/// **Every figure is the caller's.** The screen holds no default skill, no
/// default percentage and no default topic list — a renders-only screen with
/// figures baked in is a screen that will one day show them to somebody.
///
/// **No rating, no level, no points.** Same reading as the verdict screens and
/// `4.13`: a number the player has never seen is worse than silence.
class SkillMasteredScreen extends StatelessWidget {
  const SkillMasteredScreen({
    super.key,
    required this.skillName,
    required this.weekAgoPercent,
    required this.unlockedTopics,
    required this.onOpenMap,
    required this.onContinue,
  });

  /// The skill just finished, as a player reads it.
  final String skillName;

  /// Where the player stood a week ago, marked on the bar. The bar itself is
  /// full: this screen only exists at a hundred.
  final int weekAgoPercent;

  /// What finishing it opened. Empty is a real outcome and draws no panel.
  final List<String> unlockedTopics;

  /// Out to the skill map. **F5** — no map screen exists today.
  final VoidCallback onOpenMap;

  /// Straight into the first thing that opened.
  final VoidCallback onContinue;

  /// The only figure this screen states about itself: the skill is finished.
  static const int _complete = 100;

  static const double _aki = 150;
  static const double _bar = 16;

  @override
  Widget build(BuildContext context) {
    final String? next = unlockedTopics.isEmpty ? null : unlockedTopics.first;

    return CenteredStateView(
      // **Not `aki: true`.** That slot draws the resting pose and this is the
      // one moment the screen is about. The design asks for a `fan` variant;
      // three poses exist and `correct` is the celebratory one — a fourth is
      // new geometry in `design/brand/spec/`, which is a brand decision rather
      // than a screen's.
      kicker: const Aki(
        width: _aki,
        pose: AkiPose.correct,
        semanticLabel: 'Aki',
      ),
      headlineLines: <String>['${skillName.toUpperCase()},', 'DOMINADA'],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _completion(),
          if (unlockedTopics.isNotEmpty) ...<Widget>[
            const SizedBox(height: BrandShape.space3),
            _opened(),
          ],
        ],
      ),
      primary: BrandButton.primary(label: 'Ver mi mapa', onPressed: onOpenMap),
      secondary: next == null
          ? null
          : BrandButton.secondary(
              label: 'Seguir con ${next.toLowerCase()}',
              onPressed: onContinue,
            ),
    );
  }

  /// The skill at a hundred, with last week's mark still on the bar.
  Widget _completion() => CandySurface(
    borderRadius: BrandShape.radiusPanel,
    shadowOffset: BrandShape.shadowButton,
    padding: const EdgeInsets.all(BrandShape.space4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                skillName,
                style: BrandText.cardTitle(size: 14),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Success, and told by a shape: a tick, not a filled block.
                // The declared rules are explicit that a right answer is
                // marked *"con palomita de trazo verde, no con otro bloque
                // relleno"*.
                BrandIcon(
                  BrandGlyph.check,
                  size: 17,
                  color: BrandColorRole.success.color,
                ),
                const SizedBox(width: BrandShape.space1),
                Text(
                  EsMxNumber.percent(_complete),
                  style: BrandText.numeral(22),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: BrandShape.space3),
        _progressBar(),
        const SizedBox(height: BrandShape.space2),
        Text(
          'La línea marca dónde estabas hace una semana',
          style: BrandText.eyebrow(size: 12, letterSpacing: 0),
        ),
      ],
    ),
  );

  /// A full bar with last week's position struck across it.
  Widget _progressBar() => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints bar) => SizedBox(
      height: _bar,
      child: Stack(
        children: <Widget>[
          CandySurface(
            background: BrandColorRole.success.color,
            borderRadius: BrandShape.radiusSlot,
            borderWidth: BrandShape.borderWidth,
            shadowOffset: Offset.zero,
            height: _bar,
            child: const SizedBox.shrink(),
          ),
          Positioned(
            left: bar.maxWidth * weekAgoPercent / 100,
            top: 0,
            bottom: 0,
            child: Container(
              width: BrandShape.borderWidth,
              color: BrandColors.ink,
            ),
          ),
        ],
      ),
    ),
  );

  /// What opened, on the design's green panel.
  ///
  /// **Filled green, which the declared rules reserve for the one action on a
  /// screen** — *"solo un elemento lo lleva: el botón principal"*. The artwork
  /// on this document draws it anyway, panel and primary button both, so the
  /// two halves of the same source disagree. Drawn as the artwork draws it and
  /// flagged: the rule is the older claim and the one worth asking about.
  Widget _opened() => CandySurface(
    background: BrandColorRole.success.color,
    borderRadius: BrandShape.radiusPanel,
    shadowOffset: Offset.zero,
    padding: const EdgeInsets.all(BrandShape.space4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          unlockedTopicsHeading(unlockedTopics.length),
          style: BrandText.eyebrow(color: BrandColors.ink),
        ),
        const SizedBox(height: BrandShape.space2),
        Row(
          children: <Widget>[
            for (int i = 0; i < unlockedTopics.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: BrandShape.space2),
              Expanded(
                child: CandySurface(
                  borderRadius: BrandShape.radiusStatTileFlat,
                  shadowOffset: Offset.zero,
                  minHeight: BrandShape.minTouchTarget,
                  padding: const EdgeInsets.symmetric(
                    horizontal: BrandShape.space2,
                    vertical: BrandShape.space2,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unlockedTopics[i],
                    textAlign: TextAlign.center,
                    style: BrandText.cardTitle(size: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
