import 'package:meta/meta.dart';

import '../../../content/model/item.dart';

/// How many items the probe asks, at most.
///
/// Ten, because `0.4` promises *"Diez como máximo"* in as many words. The
/// number lives here so the copy and the plan cannot drift: a screen that
/// printed a different one would be a promise the flow does not keep.
const int calibrationLength = 10;

/// The items the probe will ask, in order.
///
/// **PURE** — a list in, a list out. The reading is `PackReader`'s and the
/// choosing is this, the same split `seriesPlan` already makes.
///
/// **Pack order, deliberately.** Which items place a player is the adaptive
/// question and it belongs to F4; until a rating exists, a shuffle would look
/// adaptive without being adaptive and would make *"I got this one wrong"*
/// unreproducible. Pack order also happens to be the variety the probe wants:
/// `pack_variety_test.dart` holds the shipped pack to showing all six families
/// inside its first ten items, which is exactly this window.
///
/// **A pack shorter than the probe gives a shorter probe.** Repeating an item
/// to reach ten would ask a player something they answered ninety seconds ago
/// and call it a new challenge.
List<Item> calibrationPlan(List<Item> pack) =>
    pack.take(calibrationLength).toList(growable: false);

/// The bar heights `0.5` draws over the probe, transcribed from the design.
///
/// Ten spans, none of them equal to its neighbour.
const List<double> probeBarPattern = <double>[
  22,
  16,
  22,
  14,
  20,
  14,
  22,
  16,
  20,
  14,
];

/// One bar per planned item, in the design's own heights.
///
/// **The strip encodes position and nothing else.** Every filled bar is the
/// same colour and the heights are fixed in advance, so the strip cannot leak
/// how the player is doing — which is the point of `0.4`'s *"No se califica"*,
/// and the reason a well-meant green-for-right bar would break both that
/// promise and BRD-1.
///
/// The pattern repeats rather than running out: nothing asks for more than ten
/// today, and a list that silently came back short would drop the last bars off
/// a strip that is supposed to say how many are left.
List<double> probeBarHeights(int count) => List<double>.generate(
      count < 0 ? 0 : count,
      (int index) => probeBarPattern[index % probeBarPattern.length],
      growable: false,
    );

/// What the probe can honestly say afterwards.
///
/// **Every figure here was measured on the device.** How many were asked, how
/// many were answered, how many were right and how long it took — all four come
/// from local grading, which is the whole of grading offline. There is no
/// rating and no placement in this type, because there is no rating system and
/// no placement algorithm: `user_skills` is written by nothing and
/// `GET /me/standing` answers `skills: []` for every player alive.
@immutable
class CalibrationOutcome {
  const CalibrationOutcome({
    required this.asked,
    required this.answered,
    required this.correct,
    required this.elapsed,
  });

  /// A probe nobody answered.
  static const CalibrationOutcome none = CalibrationOutcome(
    asked: 0,
    answered: 0,
    correct: 0,
    elapsed: Duration.zero,
  );

  /// How many items the probe planned to ask.
  final int asked;

  /// How many the player actually answered. Lower than [asked] when they left.
  final int answered;

  final int correct;

  /// The whole probe, not the last item.
  final Duration elapsed;

  /// Whether `0.6` has anything true to put on the screen.
  ///
  /// A player who skipped the probe outright gets no result screen at all —
  /// the same reading as the `HISTORIAL` section being absent when there is
  /// nothing true to say, rather than present and reading zero.
  bool get hasSomethingToReport => answered > 0;

  @override
  bool operator ==(Object other) =>
      other is CalibrationOutcome &&
      other.asked == asked &&
      other.answered == answered &&
      other.correct == correct &&
      other.elapsed == elapsed;

  @override
  int get hashCode => Object.hash(asked, answered, correct, elapsed);

  @override
  String toString() => 'CalibrationOutcome(asked: $asked, '
      'answered: $answered, correct: $correct, elapsed: $elapsed)';
}
