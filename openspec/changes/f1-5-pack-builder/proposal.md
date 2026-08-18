## Why

`packages/core` is finished and consumed by nothing. The rederivation machine —
splitmix64 pinned to Vigna's reference, exact rationals, Glicko-1, the template
registry, 98 tests at a 95% mutation score — has no caller, and the app plays
from 70 items hand-authored into a JSON file that is not the frozen pack format.
F1.5 is the step that joins them, and `ARCHITECTURE.md` §9 puts it on the
critical path between F1 and F2. We built F2 first to get something playable,
which was right, and it left this hole in the middle.

The second reason is what a player sees. `verdict_screen.dart` deliberately
never says "incorrecto", but today it also says nothing about *why* an answer
was wrong, because no content exists to say it with. §9 is blunt: *"without
those the error screen degrades to 'incorrecto', and offline is 100% of F2."*
`contract/fixtures/diagnosis/filled.json` is frozen and ready; nothing produces
it.

## What Changes

- **A pack builder CLI** in `packages/core`, emitting the frozen format that
  `packages/contract`'s `parsePack` already validates.
- **A pack is assembled from sources**, not generated wholesale. A source is
  either a template invocation or an authored item. This is the decision that
  keeps the app at six question families: `packages/core` ships exactly one
  template today (`arith.integer.subtract`), so a wholly generated pack would
  regress the app from six families to one.
- **The 70 authored items are lifted into the frozen envelope.** A spike ran
  them through `parsePack` and it returned `ok` for all 70 across all six
  families, with no change to any item's content — only envelope fields
  (`skill_id`, `keypad`, a digest answer, `diagnosis`) needed synthesising. All
  20 arithmetic items are already exactly `term operator term =`, so they map
  onto the frozen `{left, operator, right}` payload directly.
- **Answers travel as HMAC digests**, computed by `contract`'s `answerDigest`
  over the pack salt, replacing the plaintext answers the app's own fixture
  format carries.
- **Labelled distractors with es-MX `explain` copy**, so an item can say what a
  wrong answer got wrong. Authored content, not generated — `template.ts` says
  so, and it is a different kind of work from the rest.
- **The emitter is a pure function of its inputs.** The seed base and the pack
  salt are arguments, never a clock or a random draw, so the same inputs produce
  byte-identical output and a determinism gate is possible at all.
- **NOT in this change: the app does not read the generated pack.** Doing so
  needs HMAC-SHA256 in Dart, which means `package:crypto` joining the runtime
  allowlist under a DEP-1 audit. That is a separate decision and a separate
  slice. The app keeps reading `app/assets/packs/starter.json`; this change
  proves the emitted pack valid with committed fixtures instead.

## Capabilities

### New Capabilities

- `pack-builder`: assembling an offline pack from template invocations and
  authored items — seeds, digests, the envelope, determinism, and refusing to
  emit a pack the frozen validator would reject.
- `item-diagnosis`: the labelled distractors and es-MX copy an item carries so a
  wrong answer can be explained rather than merely marked, including what the
  copy may never say.

### Modified Capabilities

<!-- None. `offline-pack-format` is frozen and this change emits it rather than
     altering it; `offline-content` describes the app's reader, which this
     change deliberately leaves alone. -->

## Impact

- **`packages/core`** — gains `src/pack/` (pure: assembly, seed derivation,
  envelope construction) and one adapter, the CLI that writes a file. It needs
  `answerDigest` and `parsePack` from `@akimath/contract`.
  **Its zero-runtime-dependency claim survives, and is strengthened.** An
  earlier draft of this section said the opposite — that contract would become a
  runtime dependency and the claim would need revisiting. `design.md` D1 settled
  it the other way after weighing the alternatives: contract stays a
  devDependency, the builder is never reachable from `src/index.ts`, and a new
  gate walks the exported surface's imports to prove it. The claim moves from a
  comment to a checked fact rather than being given up.
- **`packages/core/pack/`** — a new directory holding the committed emitted
  pack, byte-diffed in CI the way `canon.golden.json` and the OpenAPI document
  already are. An earlier draft said `contract/fixtures/`; that would leave one
  directory with two owners and two emitters, since `contract/` is produced by
  the contract package and diffed as a unit.
- **`.github/workflows/ci.yml`** — the `core` job gains the emit-and-diff step.
- **No Dart change.** `app/` is untouched, and no dependency joins its
  allowlist.
- **The 400-day and 30-day retention figures, the schema, and the frozen pack
  format are all unaffected** — this change produces the format, it does not
  alter it.
