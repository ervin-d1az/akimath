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
