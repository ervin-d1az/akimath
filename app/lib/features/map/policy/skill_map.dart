/// What the map of topics says, read off the pack and the series cursor.
///
/// **PURE** — items in, nodes out. No pack reading, no preference, no clock.
/// `MapRoute` is the adapter that fetches both halves and hands them here.
///
/// **Every figure on this map is computed from something the app really
/// knows**, and the two sources are named rather than assumed:
///
/// - *Which topics exist* is the set of stimulus families the pack carries.
///   The design's map is drawn over nine curriculum topics — *Suma y resta*,
///   *Fracciones*, *Álgebra* — and this app has no curriculum: it has six
///   frozen question families, which is the real taxonomy the player meets.
/// - *How far a topic has been taken* is the **ladder step** the player has
///   reached in it. `CLAUDE.md` fixes offline difficulty as the pack's
///   `ladder_step`, so the hardest step a family has served is the honest
///   reading of how deep into it somebody has got. Counting answered items
///   instead would read 1/20 after the first series and stay flat for weeks.
///
/// There is deliberately **no rating and no accuracy here**. Both are F4, the
/// server returns a null `ratingDelta`, and a percentage invented on this
/// screen would be a figure sync could later contradict.
library;

import 'package:meta/meta.dart';

import '../../../content/model/item.dart';
import '../../../design/widgets/spec/mastery_level.dart';
import '../../home/policy/series_families.dart';
import 'skill_copy.dart';

/// One topic on the map.
@immutable
final class SkillNode {
  const SkillNode({
    required this.label,
    required this.blurb,
    required this.level,
    required this.reachedStep,
    required this.topStep,
  });

  /// What a player calls this family, in es-MX. `familyLabel`'s, so the map and
  /// the home cannot disagree about what a topic is called.
  final String label;

  /// The sentence `2.7` opens with.
  final String blurb;

  final MasteryLevel level;

  /// The hardest ladder step this family has served the player. Zero when the
  /// player has met none of it.
  final int reachedStep;

  /// The hardest ladder step this family offers in the pack.
  final int topStep;

  /// How far up that ladder the player is, 0..1.
  double get progress => topStep <= 0 ? 0 : reachedStep / topStep;

  /// The same figure as a whole percent, which is how `2.7` prints it.
  int get progressPercent => (progress * 100).round();
}

/// The whole map: its topics and which one the player is standing on.
@immutable
final class SkillMap {
  const SkillMap({required this.nodes, required this.focusIndex});

  final List<SkillNode> nodes;

  /// The node holding the item the next series will open with, or null when the
  /// pack carries no items at all.
  ///
  /// **One node, always**, which is what lets the map draw a single hero the
  /// way the design does. Several topics can be in progress at once; only one
  /// of them is the one the player is about to meet.
  final int? focusIndex;

  /// How many topics the player has met at all.
  int get startedCount =>
      nodes.where((SkillNode node) => node.reachedStep > 0).length;
}

/// Reads the map from the pack and how many items have been served.
///
/// [itemsServed] is `SeriesCursorStore`'s running total and **wraps**, because
/// `seriesStart` wraps: a player past the end of the pack has been served all
/// of it, and the total keeps climbing. Anything out of range is read as a
/// bound rather than thrown, so a corrupt preference costs a wrong-looking map
/// and never a crash — the same rule the store itself follows.
SkillMap readSkillMap({
  required List<Item> items,
  required int itemsServed,
}) {
  if (items.isEmpty) {
    return const SkillMap(nodes: <SkillNode>[], focusIndex: null);
  }

  final int served = itemsServed.clamp(0, items.length);
  final List<String> order = <String>[];
  final Map<String, _Ladder> ladders = <String, _Ladder>{};
  final Map<String, String> blurbs = <String, String>{};

  for (int index = 0; index < items.length; index++) {
    final Item item = items[index];
    final String label = familyLabel(item.stimulus);
    if (!ladders.containsKey(label)) {
      order.add(label);
      ladders[label] = const _Ladder();
      blurbs[label] = skillBlurb(item.stimulus);
    }
    ladders[label] = ladders[label]!.including(
      item.ladderStep,
      served: index < served,
    );
  }

  return SkillMap(
    nodes: <SkillNode>[
      for (final String label in order)
        SkillNode(
          label: label,
          blurb: blurbs[label]!,
          level: ladders[label]!.level,
          reachedStep: ladders[label]!.reached,
          topStep: ladders[label]!.top,
        ),
    ],
    focusIndex: order.indexOf(familyLabel(items[served % items.length].stimulus)),
  );
}

/// One family's difficulty ladder, accumulated as the pack is walked.
@immutable
class _Ladder {
  const _Ladder({this.reached = 0, this.top = 0});

  /// The hardest step served, **not the last one served**: an easy item after a
  /// hard one must not take progress away, or a player would watch a topic go
  /// backwards for answering.
  final int reached;

  final int top;

  _Ladder including(int step, {required bool served}) => _Ladder(
        reached: served && step > reached ? step : reached,
        top: step > top ? step : top,
      );

  /// **Never [MasteryLevel.locked], and that is the finding rather than an
  /// omission.** A locked node means a prerequisite is unmet, and this pack has
  /// no prerequisites: every family appears inside the first six items, so a
  /// player can reach any of them in their first two series. Drawing padlocks
  /// over topics nothing gates would be the map telling a lie in the one place
  /// it is most legible. The arm stays on the type, the screen draws it, and
  /// the day a pack arrives with a real gate the producer is here.
  MasteryLevel get level {
    if (reached <= 0) {
      return MasteryLevel.available;
    }
    return reached >= top ? MasteryLevel.mastered : MasteryLevel.inProgress;
  }
}
