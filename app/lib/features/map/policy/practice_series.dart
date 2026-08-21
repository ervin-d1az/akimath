/// The items a practice run on one topic plays.
///
/// **PURE** — a pack and a topic in, a list out. The same shape and the same
/// reasoning as `seriesPlan`, which this deliberately does not extend: that
/// function answers *what comes next in the run*, and this one answers *what
/// comes next in this topic*. One function answering both would be two callers
/// disagreeing about what it counts.
///
/// **Practice does not move the map.** It advances no cursor, and it must not:
/// `SeriesCursorStore` is a count of items served *in pack order*, and the map
/// reads it as "the pack up to here". Advancing it by five for a run inside one
/// family would mark four other topics as progressed for work nobody did — a
/// wrong figure on the screen whose whole job is to report progress. The map
/// moves with the daily series, which is what the cursor actually counts.
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
/// list wraps to the beginning of the topic, so practising twice in a row does
/// not serve the same five while there are others.
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
