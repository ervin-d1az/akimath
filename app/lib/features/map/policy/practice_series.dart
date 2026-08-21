/// The items a practice run on one topic plays.
///
/// **PURE** — a pack and a topic in, a list out. The same shape and the same
/// reasoning as `seriesPlan`, which this deliberately does not extend: that
/// function answers *what comes next in the run*, and this one answers *what
/// comes next in this topic*. One function answering both would be two callers
/// disagreeing about what it counts.
///
/// **Practice moves the map, and it does not move the cursor.** Those are two
/// statements and both matter. `SeriesCursorStore` is a count of items served
/// *in pack order*, and it decides which five the home serves next; advancing
/// it by five for a run inside one family would mark five other topics as
/// progressed for work nobody did **and** skip items the player has never seen.
/// What a run leaves instead is the hardest ladder step it served in that one
/// family — `policy/practised_steps.dart`, which `readSkillMap` reads alongside
/// the cursor. Before it did, the button whose whole purpose is to advance a
/// topic was structurally incapable of advancing it.
library;

import '../../../content/model/item.dart';
import '../../../features/home/policy/series_families.dart';
import '../../round/policy/series_plan.dart';

/// Up to [seriesLength] items of the topic [label], starting with the ones the
/// player has not met.
///
/// **Deterministic and deliberately dull**, for `seriesPlan`'s stated reason: a
/// shuffle would look adaptive without being adaptive, and choosing well is the
/// calibration question F4 owns. Items past [itemsServed] come first and the
/// list wraps to the beginning of the topic, so a topic the daily series has
/// already walked into opens on what is left rather than on its first item.
///
/// **Two runs in a row do serve the same five**, and this is where that is
/// written down rather than somewhere it reads as a surprise: [itemsServed] is
/// the only thing that orders them and only the daily series moves it. The
/// comment here claimed the opposite for as long as the function existed. What
/// would change it is ordering by the step the player has *reached* — which is
/// now recorded — and that is a selection decision to make on its own evidence,
/// not a rider on the one that made the number move.
List<Item> practiceSeries({
  required List<Item> items,
  required String label,
  required int itemsServed,
}) {
  final int served = itemsServed.clamp(0, items.length);
  final List<Item> unmet = <Item>[];
  final List<Item> met = <Item>[];

  for (int index = 0; index < items.length; index++) {
    if (familyLabel(items[index].stimulus) != label) {
      continue;
    }
    (index < served ? met : unmet).add(items[index]);
  }

  final List<Item> ordered = <Item>[...unmet, ...met];
  return ordered.length <= seriesLength
      ? List<Item>.unmodifiable(ordered)
      : List<Item>.unmodifiable(ordered.take(seriesLength));
}
