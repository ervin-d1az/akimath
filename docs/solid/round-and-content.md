# SOLID audit — `app/lib/features/round/` and `app/lib/content/`

Read at `653a17b`, against `CLAUDE.md` and `.claude/conventions/craftsmanship.md`. Documentation
only; no production code was changed.

## Verdict

**This module is in good shape.** The pure/adapter split is real rather than asserted — `content/`
is nine model files under `pure_boundary_test.dart`'s `content/model/` root plus two files outside
it, the round's `policy/` is six files under the `features/*/policy/` root, and every screen in
`round/ui/` takes values and callbacks rather than reaching for a pack, a clock or a store. The
sealed types are used the way a sealed type should be: `Stimulus` is dispatched once, in
`StimulusView`, for both the round and the home's preview; `ItemAnswer` is dispatched twice, in
`gradeItem` and in `diagnoseItem`, and both are exhaustive. Four of the six round policies have one
reason to change each. The five stimulus views take primitives and import no content at all.

The single most expensive thing in it is that **grading — one decision — is spread across four
files in two directories, and the seam between them was drawn by an import restriction rather than
by the domain.** `package:crypto` is not on the pure allowlist, so the half of grading that needs
it was pushed into `content/answer_digest.dart`, which then had to import *back* into
`features/round/policy/` — the only edge in the app that points from the shared content kernel into
a feature. `Item.expected`'s throw, the `content/` → `features/` inversion, and the fact that a
grading change touches four files are all the same fact seen from three sides. Nothing is broken
today; what is expensive is changing how an answer is judged, and what is fragile is that the
precondition holding it together lives in a doc comment.

Everything else below is small, and two of the five findings are stale prose rather than structure.

## The sealed answer, judged

The task asks whether `Item.answer`'s sealed `PlainAnswer | DigestAnswer` plus a throwing
`Item.expected` is a Liskov problem. **It is not, and the sealed pair is the right shape.**

`ItemAnswer` (`app/lib/content/model/item.dart:186`) declares exactly one member, `distractors`, and
both subtypes provide it. There is no member a subtype narrows, weakens or refuses. The throw is not
on the hierarchy at all: it is on `Item.expected` (`item.dart:264`), and every `Item` is the same
type, so there is no substitution taking place for a subtype to violate. The textbook LSP case would
be `ItemAnswer.expected` overridden to throw in `DigestAnswer`; that is not what is written.

What is written is a **partial function on a total type** — `Item.expected` has a precondition
(`answer is PlainAnswer`) that its signature cannot state. The design's own reasoning holds: the
alternative to throwing is returning `''`, which grades every digest item wrong and loses the round
silently, and the recorded history — the first digest item played threw, which is how `diagnose` was
caught re-deciding the verdict by calling `grade` — is the argument for loudness working exactly as
intended. Keeping `distractors` on `ItemAnswer` rather than on `Item`, so the two keyings cannot be
confused, is likewise right.

The residual cost is narrow and is folded into finding 1: `grade` is **public**, its precondition is
in prose, and it already fired once in production history.

## Findings, by cost

### 1. Grading is one decision in four files, and the seam is an import restriction

**Principle:** SRP (who asks for a change) and DIP (direction of dependency).

**Where:**

- `app/lib/content/answer_digest.dart:30-31` — `import '../features/round/policy/diagnose.dart';`
  and `import '../features/round/policy/grading.dart';`
- `app/lib/content/answer_digest.dart:95` (`gradeItem`) and `:110` (`diagnoseItem`)
- `app/lib/features/round/policy/grading.dart:27` (`grade`)
- `app/lib/features/round/policy/diagnose.dart:42` (`diagnose`)
- `app/lib/content/model/item.dart:264` (`Item.expected`)

**Cost.** To change how an answer is judged you touch four files across two directories. The split
is not along a line anybody would ask for a change on: `grade` names an `Item`, an answer and a
`Verdict`; `diagnose` names a distractor table, a key and a `Diagnosis`. Neither knows a series
exists, neither is reachable from a round-shaped type, and neither is used only by the round —
`features/onboarding/ui/calibration_item_screen.dart:105` grades through the same entry point. They
are content decisions filed under a feature, and the file that reunites them lives in `content/`.

That misfiling produces the app's one backwards edge. `content/` is the shared kernel: `home`, `map`,
`onboarding`, `puzzle`, `round` and `sync` all import it, and it imports back into exactly one
feature's `policy/`. So `features/round/` can never be renamed, split or removed without editing
`content/`, and the round's policy files can never take a round-shaped parameter — a `RoundOutcome`,
a series index — without dragging the round's types into the layer four other features depend on.
The project's own cycle gate does not see this: `findFeatureBarrelCycles`
(`app/test/architecture/pure_boundary_test.dart:334`) walks `features/*/*.dart` barrels, and no
feature has one.

The same misfiling is why `Item.expected` exists. It is a projection whose only production caller is
`grading.dart:30`, and `grade` reaches for it because it takes the wide type — an `Item` — when it
needs one string. Because `grade` is public and pure, nothing in the type system stops a second call
site importing `grading.dart` and handing it a digest item; the guard is one `switch` arm in
`gradeItem` plus a doc comment. That is a `StateError` in front of a child, mid-round, and it has
happened once already.

**Direction.** Move `grade` and `diagnose` into `content/model/`, and narrow `grade` to take the
`PlainAnswer` (or its canonical string) rather than the `Item`. That leaves `answer_digest.dart` as
the crypto adapter it genuinely is, deletes the backwards import, and makes the precondition
unstateable rather than documented — with `grade(PlainAnswer, …)` the only place that can pick the
wrong arm is the one `switch` that already exists. `Item.expected` then has no production caller and
can go. The purity gate is unaffected: `grading.dart` already imports `content/model/canon.dart`,
`content/model/item.dart` and `design/widgets/spec/verdict.dart` from inside a pure root
(`features/*/policy/`), and `content/model/` is the same kind of root with the same leaf verdicts —
`canon.dart` imports nothing at all and `verdict.dart` imports only `icons/spec/brand_glyph.dart`.

### 2. Two arithmetic paths disagree about which operators are drawable

**Principle:** one decision, one place (the SSOT half of SRP).

**Where:**

- `app/lib/content/model/stimulus_reader.dart:106-122` — `_operatorGlyphs`, a closed map of the four
  frozen operators, translating the contract's ASCII `-` to U+2212, and `_glyph`, which refuses
  anything else by name.
- `app/lib/content/model/pack.dart:288` — `Pack._operator`, which validates by calling
  `OperatorNode.of` and catching `ArgumentError`.
- `app/lib/design/math/spec/math_node.dart:464` — `OperatorNode.of` rejects only the solidus and
  accepts every other string.

**Cost.** Both paths end in an `ArithmeticStimulus` of `PromptToken`s and both are reached from
`Pack.fromJson`, but they answer "which operators may an item carry, and how is each drawn"
differently. An authored item whose `prompt` spells subtraction as the ASCII hyphen `-` passes
`_operator`, loads clean, and ships a hyphen to a learner, while the same subtraction arriving as an
`arithmetic` stimulus payload is translated to U+2212 — two typographies for one operator, in one
pack, with every gate green. The same applies to any glyph at all: `Pack._operator` would accept
`"%"` or `"±"` and hand it to the compositor.

This is **latent, one authored item away**, and nothing pins it. The shipped pack is correct by
author discipline, not by construction: `assets/packs/starter.json` uses U+2212 in all five of its
subtractions (verified against the asset — 7 `+`, 5 `−`, 5 `×`, 3 `÷`, 20 `=` across the 20 authored
`prompt` items). The two operator assertions on the authored path both point the other way —
`test/content/model/pack_test.dart:356` asserts the five glyphs the pack *does* use parse, and the
case above it asserts the solidus is refused; no test refuses anything else, and
`pack_variety_test.dart`, which is the gate that walks the shipped pack, says nothing about
operators at all. The
project has already paid for exactly this class of defect once — `canon.dart:158-175` records a
`-0/5` divergence that told a child a right answer was wrong — and the argument there was the same:
content is validated where it is read, against one rule.

**Direction.** Give the authored `prompt` path the same closed operator set the frozen path uses.
`_operatorGlyphs` is already the app's one statement of "the four operators the contract froze and
the glyph each is drawn with"; `Pack._operator` should ask it rather than asking the compositor what
it happens to be able to paint.

### 3. The round's one outward feature edge, into the home

**Principle:** acyclic dependencies; SRP as placement.

**Where:**

- `app/lib/features/round/ui/round_screen.dart:17` — `import '../../home/data/day_log_store.dart';`
- `app/lib/features/round/policy/streak_policy.dart` — imported by
  `features/home/ui/home_route.dart:12`, `features/home/policy/streak_state.dart:13`,
  `features/profile/ui/profile_route.dart:15` and `features/round/ui/round_screen.dart:19`.

**Cost.** Line 17 is the only import in all of `features/round/` that reaches another feature, and it
closes a cycle: `home` → `round` on six imports, `round` → `home` on one. The round therefore cannot
be compiled, tested or extracted without the home feature present, and so neither can
`features/onboarding/`, which pushes the same screen. In the other direction, `streak_policy.dart`
has three of its four callers outside the round, and its two functions answer to different people —
`streakLength`'s "does yesterday count" is a product rule (Q7), `weekMarks`' `weekWindow = 7` is a
home-screen design decision about a strip the round never draws.

**Direction.** Small and local: `DayLogStore` is an interface over "the days this device recorded",
which is a fact three features read and none of them owns. Note it here and fix it when the day-log
concern is next touched — the larger remedy lives in `features/home/`, which this audit did not
cover, so nothing here should be re-arranged on the strength of one import line.

### 4. Two comments state behaviour the code does not have (CMT-2)

**Principle:** not a SOLID principle — a rulebook violation found while reading, recorded because
CMT-2 makes it a defect rather than a style note.

**Where:**

- `app/lib/content/model/pack.dart:6-12`: *"`contract/pack.schema.json` carries an HMAC `digest`
  instead of a plaintext answer … reading it needs an HMAC implementation, which needs a dependency
  this project has not decided on. Until then a pack carries its answers in the clear."* The
  dependency was decided: `package:crypto` is in, `content/answer_digest.dart` is the verifier, and
  `content/model/issued_pack.dart` reads that exact format into the same `Pack` type this comment
  sits on. The file's own library doc says the app cannot do something the file beside it does.
- `app/lib/content/pack_reader.dart:10`: *"**The one adapter in `content/`.**"* Two files in
  `content/` sit outside the `content/model/` pure root, and the other one opens with *"**ADAPTER,
  and only because of the import**"* (`answer_digest.dart:3`). The task asked this to be verified, so
  precisely: `pack_reader.dart` is the only file in `content/` that performs IO — it is the only one
  touching an `AssetBundle`, and no `content/` file reads a socket, a clock or an environment. It is
  not the only file outside the pure root, and the other one labels itself an adapter too.

**Cost.** CMT-2's own argument: a reader believes a comment, which is what makes a false one worse
than none — it retires the question. `pack.dart`'s is the expensive one, because the next author
looking for "can the app read an issued pack" reads the top of the pack model and gets *no*.

**Direction.** Correct both in the change that next touches those files. `pack.dart`'s doc should say
what it now means — this reads the authored fixture format, `issued_pack.dart` reads the frozen one,
and the two produce the same type. `pack_reader.dart`'s should claim what is true and checkable: the
one file in `content/` that performs IO.

### 5. `nodeFor` has no production caller

**Principle:** SRP, read as "a module with no reason to change".

**Where:** `app/lib/features/round/policy/prompt_layout.dart:15` (`nodeFor`) and `:27` (`_promptOf`).

**Cost.** `StimulusView` (`round/ui/stimulus/stimulus_view.dart:39`) calls `nodeForTokens` directly
with the tokens it destructured from `ArithmeticStimulus`, so `nodeFor(Item)` and the throwing
`_promptOf` beneath it have no caller in `lib/` — only five cases in
`test/features/round/policy/prompt_layout_test.dart`, one of which pins the throw. The doc comment
above `_promptOf` argues at length for a catch-all arm on the grounds that a per-family arm "would
make `RoundScreen`'s exhaustive switch the *second* place a new family has to be declared" — an
argument about a call path that no longer exists, since the switch moved to `StimulusView` and
`nodeFor` left the path with it. The cost is a small one paid on every read: an `Item`-shaped
throwing entry point that looks live, and five tests that constrain nothing.

**Direction.** Delete `nodeFor` and `_promptOf`, keep `nodeForTokens`, and move the tests onto it.

## What was checked and found clean

- **`content/model/stimulus_reader.dart` — six parsers in one file is right, with one seam
  misplaced.** The classic SRP/OCP claim does not hold here, for four reasons. All six change for
  exactly one reason — the frozen contract moving — so they have one asker, not six. The shared
  helpers are genuinely shared: `requireUnknownIndex` (`:301`) bounds the hole for four of the six
  families and `_requireInt`/`_requireInts`/`_pairSide` for five, so splitting into six files would
  either duplicate them or create a seventh file every one of the six depends on — more coupling
  surface, not less. Adding a kind is three adjacent edits — `frozenStimulusKinds`, a private
  function, one `switch` arm — and the extension point is *exercised* rather than assumed: the
  fixture gate reports 6 frozen → 6 readable, so a seventh kind the contract froze fails a test
  instead of degrading silently, which is what the `final Object? kind =>` arm at `:61` refuses to
  let happen. The one leak is finding 2's: `_arithmetic` is the only parser that emits a *drawing*
  vocabulary (`PromptToken`) rather than data, so it holds two decisions — what the payload means,
  and how it is drawn (`den == 1` renders `3`, not `3/1`; `-` renders as U+2212). That seam is worth
  moving. Six parsers in one file is not.
- **`content/model/puzzle_reader.dart`** is the same arrangement for the five frozen puzzle formats
  and the same verdict applies, with a cleaner conscience: `_board`, `_cell`, `_cellSet` and
  `_requireCopy` are shared across all five, the Kakuro uniqueness exception is named rather than
  hidden, and `_wordSearch`'s in-grid check is argued for on the ground that it is a scan and not a
  solver. Read in full for its dispatch, its helpers and `_wordSearch`; the three caged-board
  parsers were skimmed rather than read line by line.
- **`content/model/canon.dart`** imports nothing at all, is a function of its input, and is held to
  the shared golden fixture. Its two recorded defects (the `-0/5` sign divergence, the tag-order
  drift found by differential fuzzing) are both fixed against the contract rather than against a
  local opinion. Clean.
- **`content/model/item.dart`** — see "The sealed answer, judged". The value types are pure data,
  `distractors` is on `ItemAnswer` for a stated and correct reason, and `Stimulus` is sealed with one
  dispatch site.
- **`content/pack_reader.dart`** holds no decision beyond "read this asset and decode it" and hands
  everything else to `Pack.fromJson`. Its one non-obvious choice — decoding the bytes rather than
  calling `loadString`, to keep an isolate out of `testWidgets`' fake-async zone — is IO, which is
  where it belongs. Clean, modulo the comment in finding 4.
- **`content/model/issued_pack.dart`** is a pure function from a decoded map to a `Pack`, refuses
  everything malformed at the door, and states its one honest compromise (`_fallback` takes the first
  skill's copy, with the condition under which that stops being honest written down). Clean.
- **`features/round/policy/` holds six files, not the three `CLAUDE.md` describes.** Four have one
  reason to change each: `answer_draft.dart` (what a keypress does to the text), `series_plan.dart`
  (which items a series serves, and its `seriesIndices`/`seriesPlan` pair exists so a caller cannot
  recompute the wrap), `grading.dart` and `diagnose.dart` — the last two **as files**: each holds one
  decision and is cohesive, and finding 1 is about where they are filed, not about what is in them.
  The other two are cohesive neither way, and both are named
  above: `streak_policy.dart` in finding 3, `prompt_layout.dart` in finding 5. The directory grew
  past its description, and two of the six no longer have the round as their primary caller.
- **`features/round/ui/`** holds no policy. `RoundScreen` keeps an index, a draft and two clocks and
  delegates every decision; `VerdictScreen` and `SeriesSummaryScreen` are functions of the summary
  types handed to them, with `DemoFigures` quarantining the two invented numbers. `StimulusView` is
  the one dispatch over `Stimulus`, shared with the home's preview card, and the five family views
  below it take `int`s and indices — none of them imports `content/` at all, which is why a change to
  a payload shape stops at the reader.
- **An exhaustive `switch` over a sealed type was not counted as an Open/Closed violation** anywhere
  — `Stimulus` in `StimulusView`, `ItemAnswer` in `gradeItem` and `diagnoseItem`, `PromptToken` in
  `nodeForTokens`. That is the analyzer doing its job.

**Candidates discarded as taste (4).** `StimulusView.scaleDown` as a boolean selecting between two
behaviours — technically FUN-2's shape, but it has one call site and no cost, and FUN-2 is a
rulebook nit rather than a SOLID finding. `Pack.fromJson` as an embedded factory against
`readIssuedPack`'s free function — an asymmetry with no cost beyond two authors editing one file.
`Pack.fromJson`'s breadth (envelope, misconceptions, distractors, items, tokens) — the only argument
available for it is size, which `dart_code_linter` already gates. `RoundScreen`'s nine constructor
parameters — every one of them is named, and FUN-1 says in as many words that the rule is about
unreadable call sites and not about arity.
