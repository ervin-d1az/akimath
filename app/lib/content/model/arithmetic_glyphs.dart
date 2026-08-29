/// The marks an arithmetic prompt is allowed to draw, stated once.
///
/// **Pure.** Two constants and a lookup; no widget, no `Canvas`, no clock.
///
/// **The frozen payload names an operator; an authored prompt names a glyph.**
/// That is the whole reason this file exists. `contract/stimulus.schema.json`
/// spells subtraction `-` — the ASCII hyphen is the contract's *name* for the
/// operation, not the mark it is drawn with — while the app's authored pack
/// format spells a prompt as the token list its compositor draws, so the mark
/// arrives already chosen. Translation therefore belongs at exactly one seam,
/// where a name becomes a glyph ([glyphForOperator], used by the frozen
/// reader); the authored reader has no name to translate and its only job is
/// to refuse a mark outside [arithmeticGlyphs].
///
/// Before this file, the authored reader asked `OperatorNode.of` instead —
/// which was asking the wrong question, because the compositor's job is to
/// draw whatever it is handed and it declines only a solidus. So the two
/// readers disagreed: an authored `-` drew a hyphen, while the same
/// subtraction returning from `POST /packs` came back as U+2212, and which
/// typography a player saw depended on whether they had an account.
library;

/// The frozen operator set, and the glyph each one is drawn with.
///
/// **They are not the same character for subtraction.** `ARITHMETIC_OPERATORS`
/// froze the ASCII hyphen `-`; the drawn mark is U+2212 MINUS SIGN, which is
/// the typographically correct one, the one every other operator in the pack
/// already uses, and the one a screen reader says as *"minus"* rather than as
/// *"hyphen"*. `math_node.dart` refuses to substitute a letter `x` for `×` on
/// that same ground. Translating here is the alternative to either drawing a
/// hyphen or reopening a frozen artifact over a code point.
const Map<String, String> operatorGlyphs = <String, String>{
  '+': '+',
  '-': '−',
  '×': '×',
  '÷': '÷',
};

/// Every mark an arithmetic prompt may draw.
///
/// **Derived from the values, never the keys** — that is the line that drops
/// the ASCII hyphen while keeping U+2212, and it is what makes an operator
/// added to the contract reach both readers in one edit.
///
/// `=` is here and not in [operatorGlyphs] because it is not an operator the
/// contract froze: the frozen reader appends it itself, having read a
/// `{left, operator, right}` payload that never mentions it, while an authored
/// prompt writes it out as a token like any other. It is drawn, so it is in
/// the drawn vocabulary.
///
/// **Unmodifiable, because a top-level `final` hands out the live set.** Four
/// features import `content/` and two test files read this; without the
/// wrapper any one of them could `add` to the closed vocabulary, and the
/// analyzer cannot see it. A file whose whole purpose is one closed set must
/// not be the thing that opens it.
final Set<String> arithmeticGlyphs =
    Set<String>.unmodifiable(<String>{...operatorGlyphs.values, '='});

/// The glyph [operator] is drawn with, or null if the contract never froze it.
String? glyphForOperator(String operator) => operatorGlyphs[operator];
