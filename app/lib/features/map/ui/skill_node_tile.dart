import 'package:flutter/widgets.dart';

import '../../../design/icons/brand_icon.dart';
import '../../../design/painting/spec/dash_spec.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/baseline_meter.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/pressable_surface.dart';
import '../../../design/widgets/spec/mastery_level.dart';
import '../../../design/widgets/spec/meter_layout.dart';
import '../policy/skill_copy.dart';
import '../policy/skill_map.dart';
import 'mastery_skin.dart';

/// How much of a topic a node has room to say.
///
/// A [SkillNodeSize] rather than a `hero` flag: a boolean parameter selecting
/// between two renderings is two functions wearing one name (FUN-2), and the
/// third size the design might yet draw would have nowhere to go.
enum SkillNodeSize {
  /// `05 Mapa de habilidades`' 100 × 62 box: a name and one mark.
  standard,

  /// Its 132 × 78 box, for the topic the next item belongs to: a name, the
  /// figure and a meter.
  hero,
}

/// One topic on the map.
///
/// **A locked topic is drawn and not pressed.** It has no shadow to travel
/// into, which in this design is what a surface looks like when it cannot be
/// pressed, and there is nothing behind it to show — so it is a `CandySurface`
/// rather than a `PressableSurface` with a dead callback.
class SkillNodeTile extends StatelessWidget {
  const SkillNodeTile({
    super.key,
    required this.node,
    required this.size,
    required this.onOpen,
  });

  final SkillNode node;
  final SkillNodeSize size;

  /// Fires only for a topic whose state opens. See [MasterySkin.opens].
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final MasterySkin skin = MasterySkin.of(node.level);
    final bool hero = size == SkillNodeSize.hero;
    final double width = hero ? _heroWidth : _standardWidth;
    final double height = hero ? _heroHeight : _standardHeight;

    final Widget body = Semantics(
      button: skin.opens,
      label: '${node.label}, ${masteryName(node.level)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BrandShape.space2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                node.label,
                maxLines: 1,
                style: BrandText.cardTitle(
                  color: skin.ink,
                  size: hero ? 14 : 12,
                ),
              ),
            ),
            const SizedBox(height: BrandShape.space1),
            _mark(skin, hero: hero),
            if (hero) ...<Widget>[
              const SizedBox(height: BrandShape.space1),
              SizedBox(
                width: _heroMeterWidth,
                child: BaselineMeter(
                  fill: node.level,
                  fraction: node.progress,
                  track: MeterTrack.hairline,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!skin.opens) {
      return CandySurface(
        width: width,
        height: height,
        background: skin.fill,
        borderRadius: hero ? BrandShape.radiusPanel : BrandShape.radiusStatTileRaised,
        borderColor: skin.ink,
        borderDash: DashSpec.locked,
        shadowOffset: skin.shadow,
        alignment: Alignment.center,
        child: body,
      );
    }

    return PressableSurface(
      onPressed: onOpen,
      width: width,
      height: height,
      background: skin.fill,
      borderRadius: hero ? BrandShape.radiusPanel : BrandShape.radiusStatTileRaised,
      borderWidth: hero ? _heroBorderWidth : BrandShape.borderWidth,
      shadow: hero ? BrandShape.shadowButton : skin.shadow,
      child: Center(child: body),
    );
  }

  /// What the box says under the name.
  ///
  /// A finished topic carries the check the design draws and a locked one the
  /// padlock — a **shape**, so the state survives a reader who cannot separate
  /// the fills (BRD-1). Everything between them prints how far up the ladder
  /// the player is, which is the one figure this app can compute.
  Widget _mark(MasterySkin skin, {required bool hero}) => switch (node.level) {
        MasteryLevel.mastered =>
          BrandIcon(BrandGlyph.check, size: _glyphSize, color: skin.ink),
        MasteryLevel.locked =>
          BrandIcon(BrandGlyph.padlock, size: _glyphSize, color: skin.ink),
        MasteryLevel.available || MasteryLevel.inProgress => Text(
            '${node.progressPercent}%',
            style: BrandText.numeral(hero ? 20 : 15).copyWith(color: skin.ink),
          ),
      };

  /// `05 Mapa de habilidades`' own boxes. They are `MapLayout`'s numbers seen
  /// from the widget side; the layout decides where a node goes and this
  /// decides how big it is, and both read the same drawing.
  static const double _standardWidth = 100;
  static const double _standardHeight = 62;
  static const double _heroWidth = 132;
  static const double _heroHeight = 78;

  /// The design thickens the hero's outline, which is the only place in the app
  /// a border steps above `BrandShape.borderWidth` (BRD-2c).
  static const double _heroBorderWidth = 4;

  /// 15 px in the design, and it does not scale with the text setting — an icon
  /// that grew inside a fixed box would burst it, which is `BrandIcon`'s own
  /// stated reason.
  static const double _glyphSize = 15;

  /// The 88 px track the design draws inside the hero.
  static const double _heroMeterWidth = 88;
}
