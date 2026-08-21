/// How far a practice run has taken the player up each topic's ladder.
///
/// **PURE** — a record in, a record out. `data/practised_step_store.dart` is
/// what keeps it between launches.
///
/// **It exists because the series cursor cannot answer this and must not be
/// made to.** `SeriesCursorStore` counts items served *in pack order*, and the
/// map reads it as "the pack up to here"; a topic run serves five items of one
/// family scattered through the pack, so advancing the cursor by five would
/// mark the other five topics as progressed for work nobody did. The daily
/// series walks the pack in order and is therefore a single integer; practice
/// does not, so it needs a record of its own. Both are facts about the same
/// thing — *the hardest step this family has served you* — and `readSkillMap`
/// takes the higher of them.
///
/// **A ladder step and not a count**, because that is what the map reads and
/// because it is the only durable half. A count of items practised means
/// nothing once the pack changes underneath it; *"you have met step 3 of
/// Series"* is still true against a pack with different items in it, and the
/// ladder the pack offers is recomputed from the pack in hand.
///
/// The keys are `familyKey`'s and never `familyLabel`'s — see there.
library;

/// The record with one more practised step in it.
///
/// **Monotone: the hardest step wins.** An easy run after a hard one must not
/// take progress away, which is the rule `_Ladder.reached` keeps in
/// `skill_map.dart` and for the same reason — a player watching a topic go
/// backwards for answering.
///
/// A [step] at or below zero is dropped rather than stored: `ladder_step` is
/// one-based in every frozen pack, and "never met" is what an absent entry
/// already says.
Map<String, int> practisedWith(
  Map<String, int> record, {
  required String family,
  required int step,
}) {
  if (step <= 0) {
    return Map<String, int>.of(record);
  }
  final Map<String, int> next = Map<String, int>.of(record);
  final int reached = next[family] ?? 0;
  if (step > reached) {
    next[family] = step;
  }
  return next;
}

/// Reads a stored record, **dropping a row it cannot read and keeping the
/// rest**.
///
/// One unreadable entry costs one topic's practice history; refusing the whole
/// record would cost all six. The same reading `PrefsAnswerRecordStore._rowsOf`
/// applies to an answer row, and for the same reason: the entries are
/// independent.
Map<String, int> readPractisedSteps(Map<String, Object?> decoded) {
  final Map<String, int> record = <String, int>{};
  for (final MapEntry<String, Object?> row in decoded.entries) {
    final Object? step = row.value;
    if (step is int && step > 0) {
      record[row.key] = step;
    }
  }
  return record;
}
