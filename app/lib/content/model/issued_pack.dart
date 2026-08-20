/// The frozen pack format, as `POST /packs` returns it.
///
/// **PURE** — a decoded map in, a [Pack] out. Reading the socket is
/// `ApiClient`'s job and verifying an answer is `answer_digest.dart`'s; this
/// only turns one shape into another.
///
/// **A second reader, not a second format.** `pack.dart` reads the app's
/// authored fixture, which carries answers in the clear because it is bundled,
/// played and graded on one device. This reads the contract's pack, which
/// carries an HMAC instead — `ARCHITECTURE.md` §4: *the answer never travels*.
/// Everything below the envelope is shared: `readStimulus` and `readPuzzle`
/// have parsed the frozen shapes since F1 and are not touched here.
///
/// **An item's id is its address.** The frozen format gives an item no id, and
/// an attempt against one names `(packId, index)`. So the id *is* that pair,
/// spelled `packId#index` — which means the thing the round already carries is
/// the thing the journal needs, with nothing to look up and nothing to keep in
/// step.
library;

import 'diagnosis.dart';
import 'item.dart';
import 'pack.dart';
import 'puzzle.dart';
import 'puzzle_reader.dart';
import 'stimulus_reader.dart';

/// How an item's `packId#index` address is spelled.
///
/// One function, because two spellings of one address is the defect that only
/// shows up as a 404 from the server.
String issuedItemId({required String packId, required int index}) =>
    '$packId#$index';

/// Splits an address back into its parts, or null if it is not one.
///
/// The journal needs the pair to submit an attempt, and it holds ids rather
/// than items — a batch waits days and several launches, and keeping a whole
/// pack alive for it would be keeping the wrong thing.
({String packId, int index})? readIssuedItemId(String id) {
  final int hash = id.lastIndexOf('#');
  if (hash <= 0 || hash == id.length - 1) {
    return null;
  }
  final int? index = int.tryParse(id.substring(hash + 1));
  if (index == null || index < 0) {
    return null;
  }
  return (packId: id.substring(0, hash), index: index);
}

/// Reads what the server issued.
///
/// Throws [FormatException] on anything malformed rather than returning a
/// partial pack: a half-read pack fails later, further away, and looks like a
/// code defect.
Pack readIssuedPack(
  Map<String, dynamic> json, {
  required String packId,
  required DateTime issuedAt,
  required DateTime expiresAt,
}) {
  final Object? rawSalt = json['pack_salt'];
  if (rawSalt is! String || rawSalt.isEmpty) {
    throw const FormatException('an issued pack must declare a pack_salt');
  }

  final Object? rawItems = json['items'];
  if (rawItems is! List || rawItems.isEmpty) {
    throw const FormatException('an issued pack must declare a non-empty items list');
  }

  final List<Item> items = <Item>[];
  for (int index = 0; index < rawItems.length; index++) {
    items.add(_item(rawItems[index], packId: packId, index: index, saltHex: rawSalt));
  }

  final Object? rawPuzzles = json['puzzles'];
  final List<Puzzle> puzzles = <Puzzle>[
    if (rawPuzzles is List)
      for (int at = 0; at < rawPuzzles.length; at++)
        readPuzzle(rawPuzzles[at], puzzleId: '$packId#puzzle$at'),
  ];

  return Pack(
    id: packId,
    issuedAt: issuedAt,
    expiresAt: expiresAt,
    items: items,
    puzzles: puzzles,
    fallbackDiagnosis: _fallback(json['skill_fallbacks']),
  );
}

Item _item(
  Object? raw, {
  required String packId,
  required int index,
  required String saltHex,
}) {
  final String id = issuedItemId(packId: packId, index: index);
  if (raw is! Map<String, dynamic>) {
    throw FormatException('item "$id" is not an object');
  }

  final Object? answer = raw['answer'];
  if (answer is! Map<String, dynamic>) {
    throw FormatException('item "$id" has no answer');
  }
  final Object? digest = answer['digest'];
  if (digest is! String || digest.isEmpty) {
    throw FormatException('item "$id" states no digest');
  }

  final Object? ladder = raw['ladder_step'];
  if (ladder is! int) {
    throw FormatException('item "$id" has no ladder_step');
  }

  return Item(
    id: id,
    stimulus: readStimulus(raw['stimulus'], itemId: id),
    // **Difficulty comes from the pack and is never computed in Dart** — the
    // same invariant the authored reader keeps.
    ladderStep: ladder,
    answer: DigestAnswer(digest: digest, saltHex: saltHex),
    // **No per-item distractors yet, and that is a stated gap.** The frozen
    // format keys them by digest — `{digest, diagnosis}` — where the authored
    // one keys them by the answer, which is exactly the change
    // `Item.distractors` predicted. Ten of eighty items carry one; the rest
    // already fall through to the pack's fallback, so an issued pack degrades
    // to the common case rather than to nothing. Wiring them is its own change,
    // because it moves the map onto `DigestAnswer` and `diagnose` with it.
  );
}

/// The pack's fallback line, from the first skill that offers one.
///
/// `skill_fallbacks` is per skill and `Pack.fallbackDiagnosis` is per pack.
/// Taking the first is honest while every entry in the shipped content says the
/// same thing; the day they differ, the round has to be handed the item's skill
/// and this becomes a lookup rather than a pick.
Diagnosis? _fallback(Object? raw) {
  if (raw is! List) {
    return null;
  }
  for (final Object? entry in raw) {
    if (entry is! Map<String, dynamic>) {
      continue;
    }
    final Object? diagnosis = entry['diagnosis'];
    if (diagnosis is! Map<String, dynamic>) {
      continue;
    }
    final Object? steps = diagnosis['steps'];
    final Object? explain = diagnosis['explain'];
    if (steps is! List || explain is! String) {
      continue;
    }
    return Diagnosis(
      steps: <String>[for (final Object? step in steps) step! as String],
      explain: explain,
    );
  }
  return null;
}
