# Decide what the item pad may offer

## Why

`docs/decisions/OPEN.md` #1 has been open since the bug hunt of 2026-08-16. The item pad draws
sixteen keys; two of them — `decimal` (`,`) and `square` (`x²`) — emit text no accepted answer can
contain, and `fix-keypad-offers-ungradable-keys` bought time by drawing both **unavailable**
(`KeypadLayout.keysWithNoGradableAnswer`, rendered at opacity 0.35 behind an `IgnorePointer` in
`app/lib/design/widgets/keypad.dart`). That is honest and it is not a decision. The entry says so
itself, and says both ways out are outside a session's authority: one alters a frozen artifact, the
other alters a drawn screen.

**This change takes no code decision. It states both options with their costs verified against the
files, recommends one, and leaves the choice to a human.**

One correction to the entry before anything else. It frames a single decision with two exits.
**It is two problems wearing one hat.** A decimal answer shape resolves the comma and leaves `x²`
exactly where it is — `5²` is not a value with a new spelling, it is an expression, and no numeric
shape can hold it. Whoever picks Option A has fixed one of the two keys.

**Phase.** The seam between F0's `f0-keypad` and F1's frozen contract, both landed.

## What already exists

| What | Where |
|---|---|
| The pad, as data | `app/lib/design/widgets/spec/keypad_layout.dart` — `KeypadLayout.item`, 16 keys, and the exclusion set |
| The renderer | `app/lib/design/widgets/keypad.dart` — chunks `keys` into `Row`s of `Expanded` by `columns` |
| The draft | `app/lib/features/round/policy/answer_draft.dart` — `acceptedCharacters`, ten digits, U+2212, `/` |
| The frozen shapes | `packages/contract/src/answer.ts` — `ANSWER_SHAPES = ["integer", "fraction"]` |
| The canonicaliser | `packages/contract/src/canon.ts` — `CHAR_MAP`, `CANONICAL_SHAPE`, `storedAnswer` |
| Its Dart twin | `app/lib/content/model/canon.dart`, held to `contract/fixtures/canon.golden.json` |
| The digest | `packages/contract/src/digest.ts` — `HMAC(pack_salt, utf8(canonical answer))` |
| The emitted artifacts | `contract/pack.schema.json`, `contract/fixtures/canon.golden.json`, `contract/fixtures/digest.golden.json` |
| The design | `TecladoReactivo` (`teclados.md` §2) — `grid-template-columns:repeat(4,1fr)`, sixteen keys, gap 10 |
| The gate that reverses either option | `app/test/design/widgets/spec/keypad_gradable_test.dart` |

## Option A — the contract grows a decimal answer shape

**What it touches.** `ANSWER_SHAPES` gains a member (`answer.ts`). `canon.ts` gains a fold for
`,`, a second accepted shape in `CANONICAL_SHAPE`, a trailing-zero rule beside `stripLeadingZeros`
(is `3,50` canonically `3.5`?), and a third branch in `storedAnswer`, whose signature is
`(numerator: bigint, denominator: bigint) → integer | fraction` and cannot express a decimal today.
`canon-vectors.ts` gains inputs, `npm run emit` rewrites `contract/pack.schema.json` and
`contract/fixtures/canon.golden.json`, and `packages/core/src/pack/build.ts` — the one caller of
`storedAnswer` — has to decide when a value is written as a decimal rather than as a fraction.

**Dart.** `app/lib/content/model/canon.dart` mirrors the same rule and is golden-tested against
the regenerated fixture, so it moves in the same change or the suite goes red.
`AnswerDraft.acceptedCharacters` gains `,`, and `keysWithNoGradableAnswer` loses `decimal` — which
the existing gate *forces*, because it re-checks every excluded key against the canonicaliser and
fails when one has started being accepted (archived D3). Nothing else in Dart reads
`answer.shape`: `issued_pack.dart` takes the digest and ignores the field.

**oasdiff sees nothing, and that is the finding.** The shape enum lives in
`contract/pack.schema.json`. In `contract/openapi.json` the pack is
`OfflinePack.pack: {"type": "object", "additionalProperties": {}}` — opaque. So
`oasdiff breaking` reports no change, the `allow-breaking-contract` label is never asked for, and
the only gate that fires is the `contract` job's `npm run emit` + `git add -A -- contract/` +
`git diff --cached --exit-code`, which fails until the regenerated artifacts are committed. A nag,
not a veto. **A change to what the HMAC is taken over would land under a green contract gate.**

**What it does to the digest — the real cost.** An item's answer is verified as
`HMAC(pack_salt, utf8(canonical spelling))`, so the canonical spelling *is* the grading rule.
Adding a shape is additive — every input accepted today canonicalises identically, so no existing
digest moves; what moves is the *tag* for inputs like `3,5`, which is a visible row in
`canon.golden.json`. The cost is one level up. `canon.dart` already records that **a fraction is
never reduced — 2/4 and 1/2 are different answers**, deliberately, because deciding they are the
same is a pedagogical call the layer does not make. A decimal shape adds a *third* spelling class
for one number: a player typing `3,5` against an item authored `7/2` is graded wrong, and neither
the pack nor the server can tell that anything went wrong, because the server holds a digest and
can only confirm or deny. **That is a grading change, not a keyboard change**, and it is the part
that needs a human.

**And it does not fix the square key.** `5²` fails `CANONICAL_SHAPE` as `non_numeric` (U+00B2 is
category No, not Nd, so it is not even caught as a non-ASCII digit). To accept it the canonicaliser
would have to either **evaluate** — `5²` → `25`, turning a speller into a calculator inside the one
module both stacks must agree on character for character — or carry a `power` shape whose canonical
form is something like `5^2`, under which a player typing the correct `25` grades wrong.
`teclados.md` §8.1 already names this: the operator set *"states that an answer is a structured
expression, not a string"*, and calls that model unbuilt.

## Option B — the two keys come off the item pad

**What the design draws.** `teclados.md` §2 transcribes `TecladoReactivo` as
`display:grid; grid-template-columns:repeat(4,1fr); gap:10px` over sixteen keys:
`7 8 9 a/b` / `4 5 6 −x` / `1 2 3 x²` / `, 0 ⌫ ➜`. Digits in calculator order, the fourth column
is the operator strip, and the bottom row deliberately breaks the pattern.

**Removal is not a deletion.** `Keypad.build` chunks `layout.keys` by `layout.columns` into `Row`s
of `Expanded` children. Delete the two entries and the pad reflows to `7 8 9 a/b` /
`4 5 6 −x` / `1 2 3 0` / `⌫ ➜` — `0` lands in the operator column and the last row's two keys
stretch to half the pad's width each. So Option B is a redrawn grid, and the design document is
read-only here (`CLAUDE.md`: *"Read it, do not write it"*), which is exactly why it is a human's
call.

**Three geometries, in ascending cost.**

1. **Two empty cells.** Keep 4×4 and 16 positions; two of them hold no key. Every remaining key
   keeps the exact position, width and fill the design draws. The amendment to the design document
   is subtractive.
2. **A reflow to fourteen keys.** Somebody draws a new bottom row and a new operator strip. Every
   key a player has already learned moves.
3. **Fill the holes.** Two keys nobody has drawn, for a pad whose content nothing needs.

**What it touches.** `KeypadLayout.item` and its `keysWithNoGradableAnswer` — which does *not*
empty but changes what it records, because an empty set can never go red when the contract grows
(design D4) — the `Keypad` renderer if geometry 1 is chosen (a grid needs a way to say "no key
here"),
`app/test/design/widgets/spec/keypad_layout_test.dart` and `keypad_gradable_test.dart`, and the
`keypad` capability's four requirements that name sixteen keys, the square key's face and the
codepoints the pad emits. Nothing under `packages/`, nothing under `contract/`, no digest, no
grading.

## Cost of leaving it as it is

**Verified low, and lower than the entry claims.** Both shipped packs were scanned:

- `app/assets/packs/starter.json` — 70 items. Zero answers contain `,`; zero contain `²`; ten are
  fractions and every one of those is typed with the live `a/b` key. Zero distractor keys contain
  either character.
- `packages/core/pack/starter.json`, the 80-item pack the server issues — 70 `integer`, 10
  `fraction`, nothing else.

Stronger than a census: `storedAnswer(numerator: bigint, denominator: bigint)` returns `integer` or
`fraction` **by signature**, so the builder cannot emit a decimal today whatever anybody authors.

What it costs instead is smaller and constant: two of sixteen keys are drawn dimmed on every item a
player answers, and the treatment is borrowed from a place where it means something else. The
puzzle board dims a digit above *this board's* ceiling — the same key is live on the next board.
On the item pad no item can ever enable these two, so the dim says "not now" where the truth is
"not ever, until somebody decides". The cost rises the day content wants a decimal answer, and at
that point the interim reads as a bug rather than as a decision — which is the entry's own
sentence, and it is right.

## Recommendation

**Option B, as geometry 1: the item pad keeps its 4×4 grid and two of its cells hold no key.**
The human decides; this is the reasoning, not the decision.

1. **Option A cannot be scoped to the problem it was proposed for.** It resolves one of the two
   keys and, in doing so, buys a third canonical spelling for numbers that already have two — with
   the grading consequence landing offline, on a device, under a contract gate that is structurally
   blind to it. Buying that to light up a key no content needs is the wrong trade.
2. **Option B removes an untruth rather than adding a capability.** A key that can never be
   pressed, on any item, is not a disabled control; it is a control that does not exist, drawn.
3. **Geometry 1 costs the design nothing it has to invent.** Every key stays where it was drawn.
   The amendment is "these two cells are empty", which a design owner can say yes or no to in one
   reading — where a reflow asks them to redraw a pad players already use.
4. **It is reversible, and the reversal is already committed.** `keysWithNoGradableAnswer` is
   checked in both directions, so the day `ANSWER_SHAPES` grows, the gate goes red and tells
   whoever grew it to put the key back. Option B does not close Option A; it stops the pad
   pretending Option A has already happened.

**The question actually being handed over is content's, not the keypad's: will AkiMath ever ask a
question whose answer is a decimal?** If yes, Option A comes first as its own change with its own
grading argument, and this one reverses itself by red test. If not yet, the pad should stop drawing
what the game cannot accept.

The rest of this proposal — `design.md`, `tasks.md` and the `keypad` delta — is written for
Option B. If the human picks A instead, none of it survives, and that is the correct shape for a
proposal whose job is to be decided rather than approved.

## Non-goals

- **Growing `ANSWER_SHAPES`.** Option A is described here so it can be chosen. It is not planned
  here, and it is not started here.
- **Any expression model.** `x²` needs one (`teclados.md` §8.1) and nothing in this repo has one.
- **Editing the design project.** `_ds/` and the Claude Design documents are read-only from a
  session. Option B needs the design owner to amend `TecladoReactivo` first; the tasks below assume
  that has happened.
- **The puzzle and OTP pads.** Neither offers a key the grader refuses.
- **`docs/decisions/OPEN.md` #1's other half.** The entry is closed by whichever option lands, and
  the closing edit belongs to that change, not to this one.
