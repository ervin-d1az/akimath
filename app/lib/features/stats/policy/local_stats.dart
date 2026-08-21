import 'package:meta/meta.dart';

import '../../../design/widgets/spec/verdict.dart';

/// One answered item, as the device remembers it.
///
/// **PURE** — a value and nothing else. Reading and writing it is
/// `data/answer_record_store.dart`.
///
/// **The device already knows this and has been throwing it away.**
/// `features/round/policy/grading.dart` decides every verdict, which is how a
/// wrong answer draws `04 Error` with no network. What the device does not do
/// is *send* it: `AttemptSubmission` deliberately carries no verdict, because
/// the frozen schema has nowhere to put one and the server regrades from the
/// item it issued. Remembering a verdict locally is a different act from
/// asserting one to the server, and nothing stopped it.
///
/// **It is the only source of an average time that exists.** `GET /me/standing`
/// is `{playerId, skills: [{skillId, rating, deviation, updatedAt}]}` with
/// `additionalProperties: false`, and `GET /me/history` reports a `score` per
/// session and no timing at all — so time on task has no wire representation in
/// either direction. For a player with no account it is the only source of
/// accuracy either.
///
/// **No identity, and that is deliberate.** Accuracy and mean time do not need
/// to know *which* item was answered, and carrying an id would raise a dedup
/// question the figures do not have: a replayed item is a second answer, and
/// counting it twice is what actually happened.
@immutable
class AnsweredItem {
  const AnsweredItem({required this.verdict, required this.elapsed});

  /// Reads one stored row, refusing anything it cannot read.
  ///
  /// **An unreadable verdict throws rather than defaulting.** Guessing `wrong`
  /// would invent a mistake the player never made, and guessing `correct` would
  /// invent a win; the store drops the row instead, which loses one answer out
  /// of a window of [answersKept] and states so.
  factory AnsweredItem.fromJson(Map<String, Object?> json) {
    final Object? verdict = json['verdict'];
    final Object? elapsedMs = json['elapsedMs'];
    if (verdict is! String || elapsedMs is! int || elapsedMs < 0) {
      throw FormatException('not an answered item', json.toString());
    }
    return AnsweredItem(
      verdict: Verdict.values.firstWhere(
        (Verdict candidate) => candidate.name == verdict,
        orElse: () =>
            throw FormatException('unknown verdict', verdict),
      ),
      elapsed: Duration(milliseconds: elapsedMs),
    );
  }

  /// What the device decided, locally, at the moment the answer was submitted.
  ///
  /// Provisional until sync, the same as every offline verdict
  /// (`ARCHITECTURE.md` §4). A figure computed from it is a figure about what
  /// this device saw, which is what the profile is reporting.
  final Verdict verdict;

  /// Time on the item, measured by `RoundScreen` between the item appearing and
  /// the answer being submitted.
  final Duration elapsed;

  /// Milliseconds, because that is the resolution `JournalledAttempt` and
  /// `AttemptSubmission` already carry — one answer, one unit.
  Map<String, Object?> toJson() => <String, Object?>{
        'verdict': verdict.name,
        'elapsedMs': elapsed.inMilliseconds,
      };

  @override
  bool operator ==(Object other) =>
      other is AnsweredItem &&
      other.verdict == verdict &&
      other.elapsed == elapsed;

  @override
  int get hashCode => Object.hash(verdict, elapsed);

  @override
  String toString() => 'AnsweredItem(${verdict.name}, ${elapsed.inMilliseconds}ms)';
}

/// How many answers the record keeps.
///
/// **A window, not a lifetime, and that is a product decision rather than a
/// storage one.** Accuracy taken over every answer a player has ever given
/// stops moving: after a thousand items a perfect day shifts the figure by a
/// tenth of a point, so the number stops being feedback and becomes a birth
/// certificate. Two hundred is forty days of the one five-item series
/// `RETO DEL DÍA` offers — long enough that one bad sitting does not define the
/// figure, short enough that a good week visibly moves it.
///
/// It bounds the storage as a consequence rather than as the reason: the record
/// is one JSON array under one key, read on the launch path, and an unbounded
/// one grows for as long as the app is installed.
///
/// **It is not `journalLimit`.** That two hundred is the server's batch ceiling
/// — a different fact that happens to share a number today. Reading one for the
/// other would let a server change silently redefine what the profile means.
const int answersKept = 200;

/// The record with one more answer in it, oldest first.
///
/// At the ceiling the **oldest** goes, which is what makes the window recent.
List<AnsweredItem> recordedWith(
  List<AnsweredItem> record,
  AnsweredItem answer,
) {
  final List<AnsweredItem> kept = <AnsweredItem>[...record, answer];
  return kept.length <= answersKept
      ? kept
      : kept.sublist(kept.length - answersKept);
}

/// What the record adds up to.
///
/// **PURE**, and the whole of the arithmetic, so no screen divides anything.
@immutable
class LocalStats {
  const LocalStats._({
    required this.answered,
    required this.correct,
    required this.totalTime,
  });

  /// Reads a record in one pass.
  factory LocalStats.of(List<AnsweredItem> record) {
    int correct = 0;
    int totalMs = 0;
    for (final AnsweredItem answer in record) {
      if (answer.verdict == Verdict.correct) {
        correct += 1;
      }
      totalMs += answer.elapsed.inMilliseconds;
    }
    return LocalStats._(
      answered: record.length,
      correct: correct,
      totalTime: Duration(milliseconds: totalMs),
    );
  }

  /// How many answers the window holds. Never more than [answersKept].
  final int answered;

  /// How many of them were right.
  final int correct;

  /// Time on task across the window. Right and wrong alike — see [meanTime].
  final Duration totalTime;

  /// The fraction that were right, or **null over no answers at all**.
  ///
  /// **Absent and not zero.** `0%` is a claim about a player who has answered
  /// nothing, and it is false: it says they got everything wrong. A screen that
  /// prints it teaches a new player that they are already failing. Null is the
  /// only honest answer, and it is what lets the section be absent — the same
  /// reading `historyWorthDrawing` applies to `HISTORIAL`.
  ///
  /// One wrong answer *is* `0`, and that is a different fact.
  double? get accuracy => answered == 0 ? null : correct / answered;

  /// [accuracy] as the whole percent a screen prints, **rounded**.
  ///
  /// Rounding is a decision — 7 of 9 is 77.7…, and truncating prints a figure a
  /// fifth of a point meaner than the truth — so it is made once here rather
  /// than at whichever call site formats it.
  int? get accuracyPercent {
    final double? fraction = accuracy;
    return fraction == null ? null : (fraction * 100).round();
  }

  /// How long an answer takes, or **null over no answers at all**.
  ///
  /// **Every answer counts, right or wrong.** The figure is *how long an item
  /// takes me*, not how long a win takes me; averaging the wins alone makes a
  /// bad sitting look fast, which is the opposite of what it is for.
  ///
  /// Truncating integer division at millisecond resolution, because that is the
  /// unit the record stores and the screens print tenths of a second.
  Duration? get meanTime => answered == 0
      ? null
      : Duration(milliseconds: totalTime.inMilliseconds ~/ answered);
}
