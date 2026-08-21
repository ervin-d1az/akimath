import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/spec/mastery_level.dart';

/// Whether a topic's outline is drawn solid or dashed.
///
/// **The shape half of the state.** Deuteranopia collapses the green and the
/// coral this app draws, and a map that said "finished" only by hue would be
/// four identical boxes to a reader who cannot separate them. A locked topic is
/// dashed, so the difference survives the colour (BRD-1) — the same
/// construction `Verdict` uses for right and wrong.
enum MasteryOutline { solid, dashed }

/// How a topic's box is drawn, resolved from its state.
///
/// **The one place a [MasteryLevel] becomes a hue on this feature**, so a
/// screen asks for a level and cannot decide what a state means by picking a
/// colour. `BaselineMeter` holds the matching decision for a meter's fill; this
/// one is for a surface, which is a different question with a different answer
/// — a meter fill of cream would be invisible and a node fill of muted grey
/// would read as disabled.
@immutable
final class MasterySkin {
  const MasterySkin._({
    required this.fill,
    required this.ink,
    required this.outline,
    required this.shadow,
    required this.opens,
  });

  factory MasterySkin.of(MasteryLevel level) => switch (level) {
        MasteryLevel.mastered => const MasterySkin._(
            fill: BrandColors.green,
            ink: BrandColors.ink,
            outline: MasteryOutline.solid,
            shadow: BrandShape.shadowTile,
            opens: true,
          ),
        MasteryLevel.inProgress => const MasterySkin._(
            fill: BrandColors.yellow,
            ink: BrandColors.ink,
            outline: MasteryOutline.solid,
            shadow: BrandShape.shadowTile,
            opens: true,
          ),
        MasteryLevel.available => const MasterySkin._(
            fill: BrandColors.surface,
            ink: BrandColors.ink,
            outline: MasteryOutline.solid,
            shadow: BrandShape.shadowTile,
            opens: true,
          ),
        // Flat on the canvas with no shadow, which is how this design says a
        // surface cannot be pressed. The design draws it exactly so.
        MasteryLevel.locked => const MasterySkin._(
            fill: BrandColors.cream,
            ink: BrandColors.muted,
            outline: MasteryOutline.dashed,
            shadow: Offset.zero,
            opens: false,
          ),
      };

  /// The surface's fill.
  final Color fill;

  /// The label, the glyph and the outline.
  final Color ink;

  final MasteryOutline outline;

  /// The hard shadow it rests on, and therefore how far it travels when
  /// pressed. `Offset.zero` for a topic that cannot be opened.
  final Offset shadow;

  /// Whether this state is something a player can open.
  ///
  /// A locked topic has nothing to say: it is not in the pack, so there is no
  /// progress to show and no practice to offer. Offering a dead screen is worse
  /// than offering nothing (DR-P2).
  final bool opens;
}
