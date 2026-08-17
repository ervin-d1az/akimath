import '../../../content/model/item.dart';

/// How many items a series plays before it ends.
///
/// Five, because `ARCHITECTURE.md` §9 fixes the first playable build as
/// *"Five items played on a plane, no account, no server"*. The number lives
/// here rather than in a screen so a widget has no opinion about how long a
/// series is, and so changing it is one edit in one pure module.
const int seriesLength = 5;

/// Where in the pack the next series starts, given how many items have been
/// played before it.
///
/// Wrapping rather than running out: four series into a pack of twenty and the
/// fifth has to come from somewhere. A player who reaches the end sees the pack
/// again, which is honest about there being twenty items and better than an
/// empty series.
int seriesStart(int itemsPlayed, int packSize) {
  if (itemsPlayed < 0) {
    throw RangeError('items played cannot be negative: $itemsPlayed');
  }
  return packSize == 0 ? 0 : itemsPlayed % packSize;
}

/// The items a series will play, in order.
///
/// **PURE** — a list in, a list out. No clock, no randomness, no pack reading:
/// the reading is `PackReader`'s and the choosing is this.
///
/// **Deterministic, and deliberately dull.** Which items a player should get is
/// the adaptive question, and it belongs to `f4-calibration`; until that exists
/// a shuffle would be the *worse* answer, because it would look adaptive
/// without being adaptive, make a report of "I got this wrong" unreproducible,
/// and leave the calibration change a behaviour to preserve that nobody chose.
/// Taking them in pack order is boring, reproducible and honestly temporary.
///
/// **A pack shorter than a series gives a shorter series.** Padding by repeating
/// would show a player something they answered ninety seconds ago and call it a
/// challenge. The shipped pack holds twenty, so this is defensive — but the
/// alternative fails silently and this one is a `clamp`.
/// **A second series is not the first series again.** `from` is how many items
/// the player has already been served, so each series continues where the last
/// one stopped and wraps at the end of the pack. Without it, the pack has twenty
/// items and a player sees five of them, forever — the first thing anyone would
/// notice.
///
/// No item repeats inside one series, whatever the offset: the count is clamped
/// to the pack, so a pack of three yields three and not the same one twice.
List<Item> seriesPlan(List<Item> pack, {int from = 0}) {
  if (pack.isEmpty) {
    return const <Item>[];
  }
  final int start = seriesStart(from, pack.length);
  final int count = seriesLength < pack.length ? seriesLength : pack.length;

  return List<Item>.generate(
    count,
    (int offset) => pack[(start + offset) % pack.length],
    growable: false,
  );
}
