/// One challenge, as pure data.
///
/// This is the shape `f1b-content-reader` will produce from a bundled pack. It
/// exists now so the round can be played from an in-app fixture without the
/// screen learning a different type later — the reader replaces the *source*,
/// not the model.
library;

import 'diagnosis.dart';

/// A piece of a rendered prompt.
///
/// **The prompt travels rendered** (`ARCHITECTURE.md` §4): the client is handed
/// what to draw, never a template and a seed to evaluate.
sealed class PromptToken {
  const PromptToken();

  const factory PromptToken.text(String value) = TextToken;
  const factory PromptToken.operator(String glyph) = OperatorToken;
  const factory PromptToken.fraction({
    required String numerator,
    required String denominator,
  }) = FractionToken;
}

final class TextToken extends PromptToken {
  const TextToken(this.value);
  final String value;
}

final class OperatorToken extends PromptToken {
  const OperatorToken(this.glyph);
  final String glyph;
}

final class FractionToken extends PromptToken {
  const FractionToken({required this.numerator, required this.denominator});
  final String numerator;
  final String denominator;
}

/// What an item asks, and therefore which renderer draws it.
///
/// **Sealed, so the seventh kind is a compile error away from being handled**
/// rather than a runtime surprise. `packages/contract` froze six kinds and the
/// app ships them one at a time; every `switch` over this type is exhaustive by
/// the analyzer, which is what makes adding a family a mechanical change
/// instead of a hunt for the places that needed updating.
sealed class Stimulus {
  const Stimulus();
}

/// `7 + 6 = ` — an expression with a blank at the end.
final class ArithmeticStimulus extends Stimulus {
  const ArithmeticStimulus(this.prompt);

  /// **The prompt travels rendered** (`ARCHITECTURE.md` §4): tokens to draw,
  /// never a template and a seed to evaluate.
  final List<PromptToken> prompt;
}

/// `2, ?, 18, 54` — a run of terms with one of them missing.
///
/// **The hole is a position, not the end.** `packages/contract` spells every
/// family that hides a tile the same way — the full run travels and
/// `unknown_index` says which one is blank — and this follows it rather than
/// inventing a second convention that a pack builder would then have to
/// translate. It is also the better puzzle: a hole in the middle asks the
/// learner to run the rule backwards.
final class NumberSeriesStimulus extends Stimulus {
  const NumberSeriesStimulus({required this.terms, required this.unknownIndex});

  /// Every term in order, **including the true value of the hidden one**.
  ///
  /// That value is on the device on purpose: offline grading needs it and so
  /// does the replay the error screen will draw. It does not contradict *the
  /// answer never travels* — that invariant is about the online item response
  /// (`ARCHITECTURE.md` §4), which carries a rendered prompt and no answer at
  /// all. What it does mean is that **the renderer must not draw
  /// `terms[unknownIndex]`**, and `number_series_view_test.dart` holds it to
  /// that.
  ///
  /// Integers, because the frozen payload says `z.array(z.int())` and because
  /// the view is what knows how to write one in es-MX. A string here would be
  /// a rendering decision made in the content.
  final List<int> terms;

  /// Which term is blank. Always a valid index into [terms].
  final int unknownIndex;
}

/// A 2×2 or 3×3 grid with one cell missing.
///
/// The rule runs along the rows and down the columns at once, and the hole is
/// where they meet — which is what makes the missing cell over-determined and
/// therefore findable rather than guessable.
final class MatrixStimulus extends Stimulus {
  const MatrixStimulus({
    required this.cells,
    required this.size,
    required this.unknownIndex,
  });

  /// Every cell in reading order, including the hidden one's true value. The
  /// renderer is what refuses to draw it, for the reason
  /// [NumberSeriesStimulus.terms] gives.
  final List<int> cells;

  /// The grid's edge length. [cells] always has `size * size` of them — the
  /// reader refuses anything else, which is why nothing downstream re-checks.
  final int size;

  /// Which cell is blank. Always a valid index into [cells].
  final int unknownIndex;
}

/// `2 › 4 · como · 5 › ?` — two pairs that share a rule.
///
/// The only family whose question is about a *relation* rather than a value.
/// The frozen payload is two `{left, right}` cards; [terms] flattens them into
/// the four-term reading order `unknown_index` already walks, because one bound
/// over four terms is the convention the contract chose and re-nesting here
/// would make the index mean something different on each side.
final class AnalogyStimulus extends Stimulus {
  const AnalogyStimulus({required this.terms, required this.unknownIndex});

  /// The four terms in reading order — first pair's left and right, then the
  /// second pair's — including the hidden one's true value.
  final List<int> terms;

  /// Which term is blank. Always a valid index into [terms].
  final int unknownIndex;
}

/// The function machine: worked examples in, one query to answer.
///
/// The only family with no `unknown_index`, because the hole is always the
/// query's output — that *is* the question. Two examples is the floor and the
/// reason is arithmetic: one example fixes no operation, since `2 › 7` is `+5`
/// and `×3+1` at the same time.
final class HiddenOperationStimulus extends Stimulus {
  const HiddenOperationStimulus({
    required this.examples,
    required this.queryInput,
  });

  /// The worked pairs, two or three of them, in the order the pack lists them.
  final List<({int input, int output})> examples;

  /// The input the learner transforms. Never one of the examples' inputs — the
  /// reader refuses that payload (`query_repeats_example`), because a query
  /// whose answer is already on screen is not a question.
  final int queryInput;
}

/// Growing dot figures with one of them missing.
///
/// The only family whose stimulus is not a number: the learner counts the
/// dots, finds the rule the counts follow, and answers with the count of the
/// figure that is blank. **How the dots are arranged is the app's decision** —
/// the payload carries counts only — which is why `figurateLayout` and not this
/// type is where the puzzle actually lives.
final class FigurateStimulus extends Stimulus {
  const FigurateStimulus({required this.dotCounts, required this.unknownIndex});

  /// Each figure's dot count in order, including the hidden one's.
  ///
  /// **Strictly increasing.** A flat or falling run has no figurate rule to
  /// find, which is `figures_not_increasing` in the frozen validator.
  final List<int> dotCounts;

  /// Which figure is blank. Always a valid index into [dotCounts].
  final int unknownIndex;
}

/// What an item's answer is known as.
///
/// **Two ways, because there are two kinds of pack.** The bundled fixture is
/// authored, shipped and played on one device, so it can carry the answer in
/// the clear. A pack the server issued cannot: `ARCHITECTURE.md` §4 says the
/// answer never travels, so the item states an HMAC of it and the device
/// verifies membership without ever holding the answer.
///
/// A sealed type rather than a nullable pair, so a reader cannot build an item
/// with both and a grader cannot forget one.
sealed class ItemAnswer {
  const ItemAnswer();

  /// Wrong answers this item anticipates, and what to say about each.
  ///
  /// **The key means a different thing on each side, which is why it lives
  /// here.** A plaintext item keys them by the answer; an issued one keys them
  /// by its digest, because a pack that listed its distractors in the clear
  /// would name the right answer by omission. One map on `Item` would be one
  /// map with two meanings, and the lookup would eventually use the wrong one.
  Map<String, Diagnosis> get distractors;
}

/// The answer itself, in the canonical form `packages/contract` froze.
final class PlainAnswer extends ItemAnswer {
  const PlainAnswer(this.canonical, {this.distractors = const <String, Diagnosis>{}});

  final String canonical;

  /// Wrong answers this item anticipates, **keyed by the answer itself**, and
  /// what to say about each.
  @override
  final Map<String, Diagnosis> distractors;
}

/// An HMAC of the answer, keyed by the pack's salt.
///
/// **The salt travels with the answer, not beside it.** It belongs to the pack,
/// and a grader that took it as a separate argument would be one a call site
/// could get wrong — or forget. Carrying it here makes a digest item
/// self-sufficient and `gradeItem` a two-argument function.
final class DigestAnswer extends ItemAnswer {
  const DigestAnswer({
    required this.digest,
    required this.saltHex,
    this.distractors = const <String, Diagnosis>{},
  });

  /// Lowercase hex, untruncated.
  final String digest;

  /// The pack's salt, as hex. Shared by every item in one pack.
  final String saltHex;

  /// Wrong answers this item anticipates, **keyed by the digest of each**.
  ///
  /// The frozen format keys them this way so that the correct answer is not the
  /// one missing from a readable list — a pack that named its distractors in
  /// the clear would name the right answer by omission.
  @override
  final Map<String, Diagnosis> distractors;
}

class Item {
  const Item({
    required this.id,
    required this.stimulus,
    required this.answer,
    required this.ladderStep,
  });


  final String id;

  /// What the item asks. One field, so there is one place to look.
  final Stimulus stimulus;

  /// How the answer is known: in the clear, or as a digest.
  ///
  /// Offline either one makes a verdict possible with no server — and
  /// provisional until sync, per the invariant.
  final ItemAnswer answer;

  /// The answer in the clear, for the fixture format that has one.
  ///
  /// Throws on a digest item, which is the point: a caller reaching for a
  /// plaintext answer that does not exist has made a mistake worth a stack
  /// trace rather than a silent empty string.
  String get expected => switch (answer) {
        PlainAnswer(:final String canonical) => canonical,
        DigestAnswer() => throw StateError(
            'item "$id" states a digest; there is no plaintext answer to read',
          ),
      };

  /// Difficulty comes from the pack and is **never computed in Dart**.
  final int ladderStep;

  /// Wrong answers this item anticipates, from whichever side knows them.
  ///
  /// A pass-through to [answer], because the keying belongs to the answer and
  /// not to the item — see `ItemAnswer.distractors`.
  Map<String, Diagnosis> get distractors => answer.distractors;
}
