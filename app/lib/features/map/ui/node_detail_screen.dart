import 'package:flutter/widgets.dart';

import '../../../design/icons/brand_icon.dart';
import '../../../design/painting/spec/dash_spec.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/baseline_meter.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/icon_button_tile.dart';
import '../../../design/widgets/spec/mastery_level.dart';
import '../policy/skill_copy.dart';
import '../policy/skill_map.dart';
import 'mastery_skin.dart';

/// `2.7 Detalle de nodo` — one topic, opened from the map.
///
/// **Two cards of the design are deliberately absent, and that is the whole
/// judgement on this screen.**
///
/// - *POR DENTRO*, the three sub-skill bars — *Mismo denominador* at 92 %,
///   *Distinto denominador* at 64 % — needs a breakdown inside a topic. There
///   is none: an item belongs to a family and to a ladder step, and nothing
///   records anything finer. Three bars at invented percentages on a screen
///   whose whole job is to report progress would be the most convincing wrong
///   thing in the app.
/// - The meter's **ink marker**, captioned *"la línea de tinta es dónde estabas
///   la semana pasada"*, needs a week-ago reading. `DayLog` records days, not
///   ladder positions, so nothing knows where the player was. [BaselineMeter]
///   takes a null baseline and draws no marker, which is the honest half of the
///   widget rather than a degraded one.
///
/// What is left is real: the topic, what it asks, the ladder step reached out
/// of the ladder the pack offers, and the topic the map arrives from. **No
/// rating** — F4 landed and `ratingDelta` is a real figure, but it is *one
/// session's* movement and this screen is *a topic*: sessions added up across a
/// topic are not a standing, and the per-skill standing that is one,
/// `GET /me/standing`, is asked for by nobody on this path. A number here is
/// still one sync could later contradict.
class NodeDetailScreen extends StatelessWidget {
  const NodeDetailScreen({
    super.key,
    required this.node,
    required this.onBack,
    this.previous,
    this.onPractise,
  });

  final SkillNode node;

  final VoidCallback onBack;

  /// The topic before this one on the map, for the *comes from* line. Null for
  /// the first topic, which has nothing before it.
  final SkillNode? previous;

  /// Starts a practice series in this topic.
  ///
  /// Optional, and absent rather than dead when a caller cannot start one — the
  /// same reading as the erasure door the account screen does not draw without
  /// a session (DR-P2).
  final VoidCallback? onPractise;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _header(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              BrandShape.space4,
              BrandShape.space3,
              BrandShape.space4,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _title(),
                const SizedBox(height: BrandShape.space3),
                Text(node.blurb, style: BrandText.body()),
                const SizedBox(height: BrandShape.space4),
                _progress(),
                const SizedBox(height: BrandShape.space3),
                _comesFrom(),
              ],
            ),
          ),
        ),
        _footer(),
      ],
    );
  }

  Widget _header() {
    final MasterySkin skin = MasterySkin.of(node.level);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrandShape.space4,
        BrandShape.space1,
        BrandShape.space4,
        0,
      ),
      child: Row(
        children: <Widget>[
          Semantics(
            button: true,
            label: 'Volver',
            child: IconButtonTile(
              onPressed: onBack,
              child: const BrandIcon(BrandGlyph.back, size: 20),
            ),
          ),
          const Spacer(),
          CandySurface(
            background: skin.fill,
            borderRadius: BrandShape.radiusControl,
            borderColor: skin.ink,
            borderDash: skin.outline == MasteryOutline.dashed
                ? DashSpec.locked
                : null,
            shadowOffset: skin.shadow,
            padding: const EdgeInsets.symmetric(
              horizontal: BrandShape.space3,
              vertical: BrandShape.space2,
            ),
            child: Text(
              masteryName(node.level).toUpperCase(),
              style: BrandText.eyebrow(color: skin.ink, letterSpacing: 0.06),
            ),
          ),
        ],
      ),
    );
  }

  /// The design's 52 px display title, shrunk only as far as a long name makes
  /// it — the same rule `DetailHeader` follows, for the same reason.
  Widget _title() => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          node.label.toUpperCase(),
          maxLines: 1,
          style: BrandText.sectionTitle(size: 52),
        ),
      );

  Widget _progress() => CandySurface(
        borderRadius: BrandShape.radiusCardSmall,
        shadowOffset: BrandShape.shadowButton,
        padding: const EdgeInsets.symmetric(
          horizontal: BrandShape.space4,
          vertical: BrandShape.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Expanded(
                  child: Text('Tu avance', style: BrandText.cardTitle(size: 13)),
                ),
                Text(
                  '${node.progressPercent}%',
                  style: BrandText.numeral(24)
                      .copyWith(color: BrandColorRole.accent.color),
                ),
              ],
            ),
            const SizedBox(height: BrandShape.space3),
            BaselineMeter(
              fill: node.level,
              fraction: node.progress,
            ),
            const SizedBox(height: BrandShape.space3),
            Text(
              masteryNote(
                level: node.level,
                reachedStep: node.reachedStep,
                topStep: node.topStep,
              ),
              style: BrandText.caption(size: 12),
            ),
          ],
        ),
      );

  Widget _comesFrom() {
    final SkillNode? before = previous;
    final bool arrivesFromFinished = before?.level == MasteryLevel.mastered;
    return CandySurface(
      borderRadius: BrandShape.radiusButton,
      shadowOffset: Offset.zero,
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Row(
        children: <Widget>[
          BrandIcon(
            arrivesFromFinished ? BrandGlyph.check : BrandGlyph.forward,
            size: 18,
            color: arrivesFromFinished
                ? BrandColorRole.success.color
                : BrandColors.muted,
          ),
          const SizedBox(width: BrandShape.space2),
          Expanded(
            child: Text(
              arrivesFrom(
                previousLabel: before?.label,
                previousLevel: before?.level,
              ),
              style: BrandText.caption(color: BrandColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    final VoidCallback? practise =
        MasterySkin.of(node.level).opens ? onPractise : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrandShape.space4,
        BrandShape.space3,
        BrandShape.space4,
        BrandShape.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (practise != null) ...<Widget>[
            BrandButton.primary(label: 'Practicar 5 retos', onPressed: practise),
            const SizedBox(height: BrandShape.space2),
          ],
          BrandButton.secondary(label: 'Volver al mapa', onPressed: onBack),
        ],
      ),
    );
  }
}
