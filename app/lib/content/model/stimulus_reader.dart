/// The six hand-written Dart parsers for the frozen stimulus payloads.
///
/// **Pure.** A decoded map in, a [Stimulus] out, a [FormatException] on
/// anything else. No file, no clock, no widget — so `stimulus_fixture_test`
/// can drive it straight from `contract/fixtures/` without building a pack.
///
/// **Why hand-written, and why in one file.** `docs/IMPLEMENTATION-PLAN.md`
/// froze the prompt as `{kind, payload}` with one schema per kind precisely
/// because a 3×3 matrix and a function machine are not a flat token list. The
/// cost it names is six parsers on the Dart side that no generator checks, and
/// the mitigation it names is `contract/fixtures/` — one golden and one
/// rejection row per kind. That is R2's remedy moved from grading to layout,
/// and it only works if the parsers are reachable from a test without a pack
/// around them. Hence this file.
///
/// The TypeScript half is `packages/contract/src/stimulus/`. When these two
/// disagree, the fixtures are right and both are wrong until they agree.
library;

import 'item.dart';

/// Every kind the frozen format declares, in the order `stimulus/index.ts`
/// lists them.
///
/// Exported so the fixture gate can assert it has a fixture for each — a kind
/// added to the contract and forgotten here would otherwise be a family the
/// app silently cannot read.
const List<String> frozenStimulusKinds = <String>[
  'arithmetic',
  'numberSeries',
  'matrix',
  'analogy',
  'hiddenOperation',
  'figurate',
];

/// Reads `{"kind": …, "payload": {…}}` into the model the round draws.
///
/// [itemId] appears in every message, because a pack failing to parse is
/// content to be fixed and the author needs to know which item.
Stimulus readStimulus(Object? raw, {required String itemId}) {
  if (raw is! Map<String, dynamic>) {
    throw FormatException('item "$itemId" has a malformed stimulus');
  }
  final Object? payload = raw['payload'];
  if (payload is! Map<String, dynamic>) {
    throw FormatException('item "$itemId" has a stimulus with no payload');
  }

  return switch (raw['kind']) {
    'arithmetic' => _arithmetic(payload, itemId),
    'numberSeries' => _numberSeries(payload, itemId),
    'matrix' => _matrix(payload, itemId),
    'analogy' => _analogy(payload, itemId),
    'hiddenOperation' => _hiddenOperation(payload, itemId),
    'figurate' => _figurate(payload, itemId),
    // Unknown kinds throw rather than degrading to something drawable: an item
    // rendered as a different question is worse than an item refused. A kind
    // the contract froze but the app has not built yet lands here too, which
    // is why the fixture gate asserts *that* rather than skipping it.
    final Object? kind => throw FormatException(
        'item "$itemId" has a stimulus kind this build cannot draw: "$kind"',
      ),
  };
}

/// `1/2 + 1/3 =` — two rational terms and an operator.
///
/// Both terms are rationals with `den: 1` standing in for an integer, which is
/// the frozen shape and is deliberate there: one term shape means the tile
/// renderer never branches on which kind of number it was handed. This
/// flattens it to the token list the compositor already draws, and *that* is
/// where the integer case reappears — `3/1` is drawn `3`, because a fraction
/// bar over a 1 is not how anyone writes three.
Stimulus _arithmetic(Map<String, dynamic> payload, String itemId) {
  final String operator = _requireString(payload, 'operator', itemId);
  final PromptToken left = _term(payload['left'], itemId);
  final PromptToken right = _term(payload['right'], itemId);

  // Division by a zero numerator is `division_by_zero_term` in the frozen
  // validator. It is checked here rather than left to the compositor because
  // the compositor would draw it perfectly happily.
  if (operator == '÷' && _numeratorOf(payload['right']) == 0) {
    throw FormatException('item "$itemId" divides by zero');
  }

  return ArithmeticStimulus(<PromptToken>[
    left,
    PromptToken.operator(_glyph(operator, itemId)),
    right,
    const PromptToken.operator('='),
  ]);
}

/// The frozen operator set, and the glyph each one is drawn with.
///
/// **They are not the same character for subtraction.** `ARITHMETIC_OPERATORS`
/// froze the ASCII hyphen `-`; the compositor draws U+2212 MINUS SIGN, which is
/// the typographically correct mark and the one every other operator in the
/// pack already uses. Translating here is the alternative to either shipping a
/// hyphen to a learner or reopening a frozen artifact over a code point.
///
/// A closed map rather than a pass-through: an operator the contract does not
/// name must not reach `OperatorNode.of`, which throws `ArgumentError` — the
/// wrong type for malformed content, and one nothing upstream catches.
const Map<String, String> _operatorGlyphs = <String, String>{
  '+': '+',
  '-': '−',
  '×': '×',
  '÷': '÷',
};

String _glyph(String operator, String itemId) {
  final String? glyph = _operatorGlyphs[operator];
  if (glyph == null) {
    throw FormatException(
      'item "$itemId" uses "$operator", which is not one of the four '
      'operators the contract froze',
    );
  }
  return glyph;
}

/// One rational term, drawn as a fraction unless its denominator is 1.
PromptToken _term(Object? raw, String itemId) {
  if (raw is! Map<String, dynamic>) {
    throw FormatException('item "$itemId" has a malformed term');
  }
  final int num = _requireInt(raw, 'num', itemId);
  final int den = _requireInt(raw, 'den', itemId);
  if (den < 1) {
    throw FormatException('item "$itemId" has a term over $den');
  }
  return den == 1
      ? PromptToken.text('$num')
      : PromptToken.fraction(numerator: '$num', denominator: '$den');
}

int _numeratorOf(Object? raw) =>
    raw is Map<String, dynamic> && raw['num'] is int ? raw['num'] as int : -1;

/// `2 · ? · 8 · 16 · 32` — a run with one term hidden.
Stimulus _numberSeries(Map<String, dynamic> payload, String itemId) {
  final List<int> terms = _requireInts(payload, 'terms', itemId);
  // Two terms fit infinitely many rules, so a series of two has no wrong
  // answer and therefore no right one. The frozen schema says `min(3)`.
  if (terms.length < 3 || terms.length > 7) {
    throw FormatException(
      'item "$itemId" has ${terms.length} terms; the format admits three to '
      'seven',
    );
  }
  return NumberSeriesStimulus(
    terms: terms,
    unknownIndex: requireUnknownIndex(payload, terms.length, itemId),
  );
}

/// A square grid with one cell hidden.
///
/// **`size` is declared, not inferred from the cell count.** That is the frozen
/// schema's decision and it is the right one: inferring would make a pack
/// truncated in transit into a silently smaller grid — a 3×3 arriving with
/// eight cells would become a valid-looking 2×2 with a spare, and the learner
/// would be shown a question nobody wrote. Declared, it is `matrix_cell_count`
/// and the item is refused.
Stimulus _matrix(Map<String, dynamic> payload, String itemId) {
  final int size = _requireInt(payload, 'size', itemId);
  if (size < 2 || size > 3) {
    throw FormatException(
      'item "$itemId" is a $size×$size grid; the format admits 2×2 and 3×3',
    );
  }
  final List<int> cells = _requireInts(payload, 'cells', itemId);
  if (cells.length != size * size) {
    throw FormatException(
      'item "$itemId" declares $size×$size but carries ${cells.length} cells',
    );
  }
  return MatrixStimulus(
    cells: cells,
    size: size,
    unknownIndex: requireUnknownIndex(payload, cells.length, itemId),
  );
}

/// Two pair-cards, flattened to the four terms the index walks.
///
/// The frozen payload nests — `pairs: [{left, right}, {left, right}]` — but
/// `unknown_index` does not: `checkAnalogy` bounds it against
/// `pairs.length * 2`, so the index is already an offset into a flat reading
/// order. Flattening here means the model, the renderer and the contract all
/// count the same way; keeping the nesting would leave the index meaning one
/// thing in the pack and another in the widget.
Stimulus _analogy(Map<String, dynamic> payload, String itemId) {
  final Object? pairs = payload['pairs'];
  // Exactly two. `z.array(...).length(2)` — one pair states a relation but
  // gives nothing to apply it to, and three is a shape no screen draws.
  if (pairs is! List || pairs.length != 2) {
    throw FormatException(
      'item "$itemId" needs exactly two pairs; an analogy compares one '
      'relation to one other',
    );
  }
  final List<int> terms = <int>[
    for (final Object? pair in pairs) ...<int>[
      _pairSide(pair, 'left', itemId),
      _pairSide(pair, 'right', itemId),
    ],
  ];
  return AnalogyStimulus(
    terms: terms,
    unknownIndex: requireUnknownIndex(payload, terms.length, itemId),
  );
}

int _pairSide(Object? pair, String side, String itemId) {
  if (pair is! Map<String, dynamic>) {
    throw FormatException('item "$itemId" has a malformed pair');
  }
  return _requireInt(pair, side, itemId);
}

/// Worked examples and the one that is left to the learner.
///
/// **The query may not repeat an example's input.** That is
/// `query_repeats_example` in the frozen validator and it is not pedantry: the
/// answer would already be on the screen, so the item would grade a reading
/// exercise. It is checked on the *input* rather than the output, because two
/// inputs mapping to the same output is ordinary (`x²` does it) while one input
/// appearing twice makes the query redundant.
Stimulus _hiddenOperation(Map<String, dynamic> payload, String itemId) {
  final Object? raw = payload['examples'];
  // Two or three. One example fixes no operation at all, and a fourth is a row
  // the screen has no height for once the query and its rule are drawn.
  if (raw is! List || raw.length < 2 || raw.length > 3) {
    throw FormatException(
      'item "$itemId" needs two or three worked examples; one fixes no rule',
    );
  }
  final List<({int input, int output})> examples = <({int input, int output})>[
    for (final Object? example in raw)
      (
        input: _pairSide(example, 'input', itemId),
        output: _pairSide(example, 'output', itemId),
      ),
  ];

  final int queryInput = _requireInt(payload, 'query_input', itemId);
  if (examples.any((({int input, int output}) e) => e.input == queryInput)) {
    throw FormatException(
      'item "$itemId" queries $queryInput, which is already a worked example — '
      'its answer would be on the screen',
    );
  }

  return HiddenOperationStimulus(examples: examples, queryInput: queryInput);
}

/// Growing dot figures with one of them missing.
///
/// **The counts must strictly increase**, which is `figures_not_increasing` in
/// the frozen validator. It is checked here and not merely trusted because a
/// flat run — 3, 3, 3 — has no rule to find and no wrong answer, and a falling
/// one contradicts the word *growing* the family is named for.
Stimulus _figurate(Map<String, dynamic> payload, String itemId) {
  final Object? raw = payload['figures'];
  // Three or four. Two figures fix no rule, and a fifth is a box the 390 px
  // row has no width for.
  if (raw is! List || raw.length < 3 || raw.length > 4) {
    throw FormatException(
      'item "$itemId" needs three or four figures; two fix no rule',
    );
  }
  final List<int> dotCounts = <int>[
    for (final Object? figure in raw) _pairSide(figure, 'dots', itemId),
  ];
  for (int i = 0; i < dotCounts.length; i++) {
    if (dotCounts[i] < 1) {
      throw FormatException('item "$itemId" has a figure of ${dotCounts[i]} dots');
    }
    if (i > 0 && dotCounts[i] <= dotCounts[i - 1]) {
      throw FormatException(
        'item "$itemId" has figures ${dotCounts.join(", ")}, which do not grow',
      );
    }
  }
  return FigurateStimulus(
    dotCounts: dotCounts,
    unknownIndex: requireUnknownIndex(payload, dotCounts.length, itemId),
  );
}

/// Which tile is blank, bounded against the run it indexes.
///
/// Shared, because every family that hides a tile bounds it identically — the
/// TypeScript half factored the same check out as `checkUnknownIndex`, and
/// this is its Dart counterpart. Out of range would otherwise be a range error
/// thrown in `build`, mid-round, past the point where "content is validated
/// where it is read" is true.
int requireUnknownIndex(
  Map<String, dynamic> payload,
  int arity,
  String itemId,
) {
  final Object? index = payload['unknown_index'];
  if (index is! int || index < 0 || index >= arity) {
    throw FormatException(
      'item "$itemId" hides tile $index of $arity, which is not one of them',
    );
  }
  return index;
}

List<int> _requireInts(Map<String, dynamic> payload, String key, String id) {
  final Object? raw = payload[key];
  if (raw is! List) {
    throw FormatException('item "$id" has no $key list');
  }
  return <int>[
    for (final Object? value in raw)
      if (value is int)
        value
      else
        throw FormatException('item "$id" has a non-integer in $key'),
  ];
}

int _requireInt(Map<String, dynamic> payload, String key, String id) {
  final Object? value = payload[key];
  if (value is! int) {
    throw FormatException('item "$id" has no integer $key');
  }
  return value;
}

String _requireString(Map<String, dynamic> payload, String key, String id) {
  final Object? value = payload[key];
  if (value is! String) {
    throw FormatException('item "$id" has no string $key');
  }
  return value;
}
