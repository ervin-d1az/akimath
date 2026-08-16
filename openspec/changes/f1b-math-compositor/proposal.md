## Why

**This is the only thing standing between F0 and a playable build**, and R1 in
`docs/IMPLEMENTATION-PLAN.md` §6 names it as the risk every estimate underrates by roughly 2×. The
work nobody schedules is the week of visual iteration that fits a 3 px outline onto thin glyphs
without the fraction bar colliding with the numerals above and below it.

Nothing in `app/lib/` renders an expression today. Every screen that shows a challenge — the item
screen, the two verdict screens, onboarding, calibration — is blocked on it, and so is every screen
that prints a measured number, because es-MX number formatting lands in the same change and there is
currently no module that owns it.

**Phase: F1b** (`ARCHITECTURE.md` §9), and Spike B runs first.

## What Changes

- **`app/lib/design/math/spec/`** — the pure half. `MathNode` lays an expression out from *injected*
  font metrics and constructs no `Path`; `FractionMetrics` derives bar thickness and minimum bar
  width from the numeral size; `EsMxNumber` owns every number the app prints.
- **`app/lib/design/math/`** — the adapter half. `MathView` paints what the spec laid out.
  `ExpressionRow` and `AnswerSlot` compose it.
- **A fraction is stacked, never inline.** No solidus form exists in the API, so no caller can emit
  one.
- **Number formatting becomes a single module** with a comma decimal separator, U+202F for
  thousands and U+2212 for a leading minus — so no caller composes a minus sign by hand.

**Not breaking:** nothing depends on this yet.

## Capabilities

### New Capabilities
- `math-composition`: how an arithmetic expression is laid out and painted, and how every number the
  app displays is formatted for es-MX.

### Modified Capabilities

None. No existing spec's requirements change.

## Impact

- **New:** `app/lib/design/math/spec/{math_node,fraction_metrics,es_mx_number}.dart` and
  `app/lib/design/math/{math_view,expression_row,answer_slot,fraction_glyph}.dart`.
- **New tests:** five files under `app/test/design/math/`.
- **`app/lib/design/math/spec/` becomes a declared pure root** in
  `app/test/architecture/pure_boundary_test.dart`, which today reports it absent.
- **No new dependency.** Font metrics are read from the already-bundled font files and injected as
  plain data, so nothing is added to `pubspec.yaml` and `req-icon-spec`'s allowlist is untouched
  (DEP-1).
- **No LaTeX library**, per `CLAUDE.md`'s Never list. The layout is ours.

## Non-goals

- **A general box-layout engine.** `MathLayout` — arbitrary nesting, radicals, real superscripts — is
  **deferred pending Spike B's exit criterion**. No document in the corpus draws a radical or a true
  superscript, and `x²` is a character append. The name stays in the inventory; the capability is
  Spike B's to earn.
- **Animation.** Motion is F8.
- **Rendering the keypad.** That is `f0-keypad`; this change renders what the keypad produces.
- **Grading an answer.** The compositor displays; it never decides whether an answer is right.
- **Deciding the answer's canonical form.** `packages/contract` froze that already.

## What this builds on

- **`app/lib/design/tokens/`** — the shape, colour and type scale, landed in `f0-token-scale`.
- **`app/lib/design/brand/spec/`** versus the painter beside it — the PURE-1 precedent this change
  follows exactly, and the one `openspec/config.yaml` cites by name.
- **`app/test/architecture/pure_boundary_test.dart`** — landed in `f0-invariant-tests`; it walks the
  import graph transitively, so declaring the new spec root is enough to make the boundary a red
  build rather than a convention.
- **The fonts are already bundled**: Darumadrop and Plus Jakarta Sans ship in `app/assets/`.
