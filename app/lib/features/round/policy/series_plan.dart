import '../../../content/model/item.dart';

/// How many items a series plays before it ends.
///
/// Five, because `ARCHITECTURE.md` §9 fixes the first playable build as
/// *"Five items played on a plane, no account, no server"*. The number lives
/// here rather than in a screen so a widget has no opinion about how long a
/// series is, and so changing it is one edit in one pure module.
const int seriesLength = 5;

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
List<Item> seriesPlan(List<Item> pack) =>
    pack.take(seriesLength).toList(growable: false);
