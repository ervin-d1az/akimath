/// A bundle of items the app plays offline.
///
/// Pure: parsing is a function from a decoded map to a value, and expiry takes
/// `now` as a parameter. Reading the file is `PackReader`'s job, beside this.
///
/// **This is the app's offline fixture format, not the frozen contract pack.**
/// `contract/pack.schema.json` carries an HMAC `digest` instead of a plaintext
/// answer — that is the membership verifier `ARCHITECTURE.md` §4 describes, and
/// reading it needs an HMAC implementation, which needs a dependency this
/// project has not decided on. Until then a pack carries its answers in the
/// clear, which is safe precisely because nothing ships: the pack is authored,
/// bundled and played entirely on one device.
library;

import 'diagnosis.dart';
import '../../design/math/spec/math_node.dart';
import 'canon.dart';
import 'item.dart';
import 'puzzle.dart';
import 'puzzle_reader.dart';
import 'stimulus_reader.dart';

class Pack {
  const Pack({
    required this.id,
    required this.issuedAt,
    required this.expiresAt,
    required this.items,
    this.puzzles = const <Puzzle>[],
    this.fallbackDiagnosis,
  });

  /// Parses a decoded pack.
  ///
  /// Throws [FormatException] on anything malformed rather than returning a
  /// partial pack. Content is the thing most likely to be edited by hand, and a
  /// half-read pack fails later, further away, and looks like a code defect.
  factory Pack.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      throw const FormatException('a pack must declare a non-empty items list');
    }

    // The copy once per pack, keyed by the same misconception ids the builder
    // uses (design D2). Seventy items each carrying four lines of es-MX would
    // be most of the file.
    final Map<String, Diagnosis> misconceptions = _misconceptions(json);

    return Pack(
      id: _requireString(json, 'pack_id'),
      issuedAt: _requireTime(json, 'issued_at'),
      expiresAt: _requireTime(json, 'expires_at'),
      items: <Item>[
        for (final Object? entry in rawItems) _item(entry, misconceptions),
      ],
      fallbackDiagnosis: misconceptions[fallbackMisconception],
      // Optional: the app's own fixture format predates puzzles and the many
      // packs that carry none stay valid.
      puzzles: <Puzzle>[
        for (final Object? entry in (json['puzzles'] as List<dynamic>?) ?? const <Object?>[])
          readPuzzle(entry, puzzleId: 'puzzle'),
      ],
    );
  }

  final String id;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final List<Item> items;

  /// The boards this pack carries. Empty is ordinary.
  final List<Puzzle> puzzles;

  /// What `04 Error` says when no distractor anticipated the answer.
  ///
  /// **Null when the pack declares no misconceptions at all**, which keeps the
  /// field optional and every pack written before this valid — such a pack
  /// simply leaves the error screen as bare as it was.
  final Diagnosis? fallbackDiagnosis;

  /// Whether this pack has expired **at the moment the caller names**.
  ///
  /// `now` is a parameter and not a clock read, which is what lets expiry be
  /// tested by handing it two dates rather than by faking time.
  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// The id every pack carrying diagnoses must define.
  ///
  /// The same one `packages/core/content/misconceptions.json` uses, so the copy
  /// is portable in both directions.
  static const String fallbackMisconception = 'no_specific_diagnosis';

  static Map<String, Diagnosis> _misconceptions(Map<String, dynamic> json) {
    final Object? raw = json['misconceptions'];
    if (raw == null) {
      return const <String, Diagnosis>{};
    }
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('misconceptions must be an object');
    }

    final Map<String, Diagnosis> read = <String, Diagnosis>{
      for (final MapEntry<String, dynamic> entry in raw.entries)
        entry.key: _diagnosis(entry.key, entry.value),
    };
    if (!read.containsKey(fallbackMisconception)) {
      // Without it, an unanticipated wrong answer — the common case — would
      // reach the screen with nothing to say, which is the state this whole
      // format exists to leave behind.
      throw const FormatException(
        'a pack with misconceptions must define "$fallbackMisconception"',
      );
    }
    return read;
  }

  static Diagnosis _diagnosis(String id, Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw FormatException('misconception "$id" must be an object');
    }
    final Object? rawSteps = raw['steps'];
    if (rawSteps is! List || rawSteps.isEmpty || rawSteps.length > 4) {
      throw FormatException('misconception "$id" needs one to four steps');
    }
    return Diagnosis(
      steps: <String>[
        for (final Object? step in rawSteps)
          if (step is String && step.isNotEmpty)
            step
          else
            throw FormatException('misconception "$id" has an empty step'),
      ],
      explain: _requireString(raw, 'explain'),
    );
  }

  /// The wrong answers an item anticipates, resolved to copy.
  ///
  /// Three refusals, all at load, all naming the item — because each of them
  /// otherwise surfaces as a screen that says nothing, on a device, with no
  /// way to report it:
  ///
  /// - an id the pack does not define,
  /// - a key the canonicaliser cannot read, which is a distractor no answer can
  ///   ever match,
  /// - a key that is the item's own answer, which is the leak the frozen
  ///   format's D3 exists to prevent.
  static Map<String, Diagnosis> _distractors(
    Map<String, dynamic> entry,
    String id,
    String answer,
    Map<String, Diagnosis> misconceptions,
  ) {
    final Object? raw = entry['distractors'];
    if (raw == null) {
      return const <String, Diagnosis>{};
    }
    if (raw is! Map<String, dynamic>) {
      throw FormatException('item "$id" has a malformed distractor table');
    }

    // `_item` has already refused an answer the canonicaliser cannot read, so
    // this cannot be null by the time it runs.
    final String? canonicalAnswer =
        canonicalise(answer, mode: CanonMode.stored).value;
    final Map<String, Diagnosis> table = <String, Diagnosis>{};
    for (final MapEntry<String, dynamic> distractor in raw.entries) {
      final CanonResult key =
          canonicalise(distractor.key, mode: CanonMode.stored);
      if (!key.ok) {
        throw FormatException(
          'item "$id" keys a distractor by "${distractor.key}", which is not a '
          'readable answer (${key.tag}) — nothing a player types could match it',
        );
      }
      if (key.value == canonicalAnswer) {
        throw FormatException(
          'item "$id" keys a distractor by its own answer "${distractor.key}"',
        );
      }
      final Object? named = distractor.value;
      final Diagnosis? copy =
          named is String ? misconceptions[named] : null;
      if (copy == null) {
        throw FormatException(
          'item "$id" names the misconception "$named", which the pack does '
          'not define',
        );
      }
      table[distractor.key] = copy;
    }
    return table;
  }

  static Item _item(Object? entry, Map<String, Diagnosis> misconceptions) {
    if (entry is! Map<String, dynamic>) {
      throw const FormatException('an item must be an object');
    }

    final String answer = _requireString(entry, 'answer');
    // Content is validated where it is read. A pack whose answer is not
    // storage-canonical would show a player a wrong verdict for a right answer,
    // on a device, with nothing reporting an error — which is exactly what
    // happened to the hand-written fixture before this check existed.
    final CanonResult canonical =
        canonicalise(answer, mode: CanonMode.stored);
    if (!canonical.ok) {
      throw FormatException(
        'item "${entry['id']}" stores a non-canonical answer '
        '"$answer" (${canonical.tag})',
      );
    }

    final String id = _requireString(entry, 'id');
    return Item(
      id: id,
      expected: answer,
      // Difficulty travels with the item. Rating never runs in Dart.
      ladderStep: _requireInt(entry, 'ladder_step'),
      stimulus: _stimulus(entry),
      distractors: _distractors(entry, id, answer, misconceptions),
    );
  }

  /// What the item asks.
  ///
  /// **An item carries exactly one of `prompt` or `stimulus`, never both and
  /// never neither.** `prompt` is the arithmetic shorthand the format shipped
  /// with and it stays, because rewriting twenty authored items to say
  /// `{"kind": "arithmetic"}` around the same token list buys nothing. Refusing
  /// *both* is what keeps that from becoming a silent default: an item with a
  /// `stimulus` the reader does not understand must not quietly fall back to a
  /// `prompt` that happens to also be there.
  static Stimulus _stimulus(Map<String, dynamic> entry) {
    final Object? rawPrompt = entry['prompt'];
    final Object? rawStimulus = entry['stimulus'];

    if (rawPrompt != null && rawStimulus != null) {
      throw FormatException(
        'item "${entry['id']}" carries both a prompt and a stimulus; '
        'it asks one question, so it declares one',
      );
    }

    if (rawStimulus != null) {
      // Delegated, because the six per-kind parsers are the thing the frozen
      // fixtures test directly and they cannot be reached through a whole pack
      // — a fixture's answer is an HMAC digest, which this format does not
      // carry yet.
      return readStimulus(rawStimulus, itemId: '${entry['id']}');
    }

    if (rawPrompt is! List || rawPrompt.isEmpty) {
      throw FormatException('item "${entry['id']}" has no prompt');
    }
    return ArithmeticStimulus(<PromptToken>[
      for (final Object? token in rawPrompt) _token(token),
    ]);
  }

  static PromptToken _token(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('a prompt token must be an object');
    }
    return switch (raw['kind']) {
      'text' => PromptToken.text(_requireString(raw, 'value')),
      'operator' => _operator(_requireString(raw, 'glyph')),
      'fraction' => PromptToken.fraction(
          numerator: _requireString(raw, 'numerator'),
          denominator: _requireString(raw, 'denominator'),
        ),
      // Unknown kinds throw rather than being skipped: a prompt silently
      // missing a term renders a different question than the one authored.
      final Object? kind =>
        throw FormatException('unknown prompt token kind "$kind"'),
    };
  }

  /// An operator token, refused at parse if the compositor cannot draw it.
  ///
  /// `OperatorNode.of` throws on a solidus — an inline fraction is not something
  /// it declines to draw, it is something it cannot express. Without this the
  /// throw happened in `build`, mid-round, when that item's turn came: past the
  /// point where "content is validated where it is read" is true, and presented
  /// to a child as a red screen.
  static PromptToken _operator(String glyph) {
    try {
      OperatorNode.of(glyph);
    } on ArgumentError catch (error) {
      throw FormatException('unusable operator "$glyph": ${error.message}');
    }
    return PromptToken.operator(glyph);
  }

  static String _requireString(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('"$key" must be a non-empty string');
    }
    return value;
  }

  static int _requireInt(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! int) {
      throw FormatException('"$key" must be an integer');
    }
    return value;
  }

  static DateTime _requireTime(Map<String, dynamic> json, String key) {
    final DateTime? parsed = DateTime.tryParse(_requireString(json, key));
    if (parsed == null) {
      throw FormatException('"$key" is not a timestamp');
    }
    return parsed.toUtc();
  }
}
