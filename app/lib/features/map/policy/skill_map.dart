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
///   **Two things serve items and both are read.** The daily series walks the
///   pack in order, so one integer — the cursor — says everything about it. A
///   practice run walks one family, scattered through the pack, so a pack
///   position cannot describe it and it keeps its own record
///   (`practised_steps.dart`). Both are lower bounds on the same fact, so this
///   takes the higher; before it did, the one button whose whole purpose is to
///   advance a topic was structurally incapable of advancing it.
///
/// There is deliberately **no rating and no accuracy here**. This policy is
/// computed from the pack and reads nothing the server holds; `ratingDelta` is
/// a real figure since F4, but it is one session's movement rather than a
/// topic's standing, and a percentage invented on this screen would be a figure
/// sync could later contradict.
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
/// [practisedSteps] is `PractisedStepStore`'s record, keyed by `familyKey`. An
/// entry naming a family this pack does not carry draws no node, and one past
/// the ladder this pack offers is read as its top — the record outlives any one
/// pack, because a family and a step mean the same thing against a different
/// set of items.
///
/// **[focusIndex] stays the cursor's alone**, and deliberately: it answers
/// *which topic does the next daily series open with*, which is a fact about
/// pack order that practice does not change.
SkillMap readSkillMap({
  required List<Item> items,
  required int itemsServed,
  required Map<String, int> practisedSteps,
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
    final String key = familyKey(item.stimulus);
    if (!ladders.containsKey(key)) {
      order.add(key);
      ladders[key] = _Ladder(practised: practisedSteps[key] ?? 0);
      blurbs[key] = skillBlurb(item.stimulus);
    }
    ladders[key] = ladders[key]!.including(
      item.ladderStep,
      served: index < served,
    );
  }

  return SkillMap(
    nodes: <SkillNode>[
      for (final String key in order)
        SkillNode(
          label: _labelOf(items, key),
          blurb: blurbs[key]!,
          level: ladders[key]!.level,
          reachedStep: ladders[key]!.reached,
          topStep: ladders[key]!.top,
        ),
    ],
    focusIndex: order.indexOf(familyKey(items[served % items.length].stimulus)),
  );
}

/// What a player calls the family [key] names, taken from the pack rather than
/// from a second switch: the pack is where the stimulus lives, and a mapping
/// written twice is a mapping that can disagree with itself.
String _labelOf(List<Item> items, String key) => familyLabel(
      items.firstWhere((Item item) => familyKey(item.stimulus) == key).stimulus,
    );

/// One family's difficulty ladder, accumulated as the pack is walked.
@immutable
class _Ladder {
  const _Ladder({this.cursorReached = 0, this.practised = 0, this.top = 0});

  /// The hardest step the **daily series** served, **not the last one served**:
  /// an easy item after a hard one must not take progress away, or a player
  /// would watch a topic go backwards for answering.
  final int cursorReached;

  /// The hardest step a **practice run** served, as this family's record holds
  /// it. Fixed for the whole walk — it is read once, not accumulated.
  final int practised;

  final int top;

  /// The hardest step this family has served the player, **whichever way it
  /// served it**, and never past the ladder this pack offers: the record
  /// outlives a pack, and a heavier one behind it must read as mastered rather
  /// than as more than a whole.
  int get reached =>
      (cursorReached > practised ? cursorReached : practised).clamp(0, top);

  _Ladder including(int step, {required bool served}) => _Ladder(
        cursorReached:
            served && step > cursorReached ? step : cursorReached,
        practised: practised,
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
