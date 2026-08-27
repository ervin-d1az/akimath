## Why

`app/lib/design/tokens/` names 14 colours, 4 radii, 1 standard border width and 4 shadow offsets.
The 69 screens the design documents draw use more than that, and BRD-2b makes the shortfall a hard
block rather than a nicety: no colour literal may exist outside `app/lib/design/tokens/`, and
`grep -rn "Color(0x" app/lib` returns only `brand_colors.dart` today. A screen that needs
`#EAE6F0` — the backspace-key fill and the skeleton-block fill — cannot be built without either
widening the palette or breaking that rule. The same holds for geometry: `Offset(4, 6)` is the most
common shadow in the app, has no name, and is **already written as a literal** at
`app/lib/design/widgets/speech_bubble.dart:43`.

This is the root of the F0 fan (`docs/IMPLEMENTATION-PLAN.md` §5.4). `f0-pressable-surface`,
`f0-dashed-border`, `f0-brand-icons`, `f0-keypad` and `f0-stat-readouts` all depend on it. Widening
the scale once, here, is what stops it being widened one constant at a time inside screen changes
that had other business.

**Phase: F0** (`ARCHITECTURE.md` §9 — scaffolding, before the F1/F1b lanes fork).

## What Changes

- **`BrandColors` gains three colours and `BrandColorRole` gains one role.** `quiet` (`#EAE6F0`),
  `pinkFigure` (`#FF9EC1`), `hairline` (ink at 18%), and `BrandColorRole.focus → pink`. The role is
  permitted by the invariant as it is actually tested — `brand_colors_test.dart` asserts pink is not
  `error`, `success` or `action`, never that no role resolves to pink (plan D18).
- **`BrandShape` gains eight radii, two border widths and two shadow offsets.** `radiusSlot 12`,
  `radiusChip 14`, `radiusControl 16`, `radiusButton 20`, `radiusCardSmall 22`, `radiusPanel 24`,
  `radiusCardMedium 26`, `radiusSheet 32`, `borderWidthThin 2.5`, `borderWidthField 2`,
  `shadowButton (4, 6)`, `shadowDot (2, 3)`. Nothing existing is renamed or removed.
- **`BrandText` gains parameters, not styles.** `numeral(size)` (Darumadrop 400 at `height: 1`),
  `eyebrow({size, letterSpacing})` with tracking expressed in em, `cardTitle({size})`,
  `body({height})`, `caption({size, height})`. No new style is added; five existing ones stop being
  fixed at one size.
- **Two architecture gates land with the tokens that make them satisfiable.**
  `app/test/architecture/no_color_literal_test.dart` turns BRD-2b's manual `grep` into a red build,
  and `app/test/architecture/no_geometry_literal_test.dart` does the same for `Offset(` literals on
  widget surfaces.
- **`speech_bubble.dart` reads `BrandShape.shadowButton`** instead of its `Offset(4, 6)` literal.
  This is the one edit that makes the geometry gate green.
- **`0.1 Splash` is re-measured to the design's figures** (plan D19, which makes the design
  authoritative on measurements): `Aki(width: 210)` not 222, three uniform 26 px gaps not 28/28/36,
  and the `width: 4` border BRD-2c names as unjustified reverts to `BrandShape.borderWidth`.
- **Four doc corrections land in the same session (PROC-6).** `BrandFonts.display`'s comment, which
  forbids the usage every design document depends on; `CLAUDE.md`'s pink invariant, narrowed to
  verdicts by D18; and `craftsmanship.md`'s BRD-1, BRD-2b and BRD-2c, which restate the same two
  sentences and go stale with them.

No dependency is added (DEP-1 is not engaged), and no product code outside `app/lib/design/tokens/`,
`app/lib/design/widgets/speech_bubble.dart` and `app/lib/features/splash/splash_screen.dart` is
touched.

## Non-goals

`docs/IMPLEMENTATION-PLAN.md` §3.2 is a table shared by the whole F0 fan. Everything in it that is
**not** listed above belongs to another change and is excluded here:

- **`SpeechBubble`'s `tailSide` / `tailInset` / `padding` / `textStyle`.** Only the `Offset(4, 6)`
  literal is replaced. The bubble keeps one tail side and one padding.
- **`CandySurface`'s `borderColor`, `borderDash` and nullable `shadowOffset`.** `borderDash` carries
  BRD-1's shape clause and D22 pins it to `f0-dashed-border`, which amends the no-blur gate in the
  same change. `CandySurface` is not opened here at all.
- **The `.card` / `.pill` / `.tile` named constructors.** They stay exactly as they are; §3.1's
  restriction on using them for product screens is a doc-comment change owned by the change that
  first draws a product screen.
- **`brand_shapes.dart`'s mark extensions** (nullable `InkRect.fill`, `DashSpec?` on
  `InkRect`/`InkStroke`) — `f0-dashed-border`.
- **`AkiSpec.tailCurl`** — owned by the change that draws the hidden-operation machine, not by the
  token scale.
- **Micro-geometry.** Fraction bar radii, dot rings, cage corners, figurate dot radii and board
  hairline widths do **not** enter `BrandShape` (§3.3, D2). They belong to the spec module that
  draws them. `BrandShape` governs widget surfaces.
- **A runtime palette.** `BrandColors` stays `static const`; "Alto contraste" (§7 Q8) is not in F0.
- **`PressableSurface`, `Verdict`, `DashSpec`, `BrandIconSpec`** and every other §3.3 component.
  This change ships constants and two gates, no new widget.

## Capabilities

### New Capabilities

- `design-tokens`: the named palette, shape scale and type scale every screen reads from, and the
  two gates that keep colour and shadow literals out of the rest of `app/lib/`.

### Modified Capabilities

None. `openspec/specs/` is empty — `BrandColors`, `BrandShape` and `BrandText` exist as code with no
spec behind them, so their obligations are written down for the first time here.

## Impact

**Code this builds on, all of it already on disk:**

| Path | What this change does to it |
|---|---|
| `app/lib/design/tokens/brand_colors.dart` | +3 colours, +1 `BrandColorRole` member |
| `app/lib/design/tokens/brand_shape.dart` | +8 radii, +2 border widths, +2 shadow offsets |
| `app/lib/design/tokens/brand_typography.dart` | 5 styles gain parameters; `BrandFonts.display` doc comment rewritten |
| `app/lib/design/widgets/speech_bubble.dart` | one literal → `BrandShape.shadowButton` |
| `app/lib/features/splash/splash_screen.dart` | Aki 222 → 210, gaps 28/28/36 → 26/26/26, tile border 4 → 3 |
| `app/test/design/tokens/brand_colors_test.dart` | extended (5 tests today) |
| `app/test/features/splash_screen_test.dart` | extended (3 tests today) |
| `app/test/design/tokens/brand_shape_test.dart` | **new** — no test covers `BrandShape` today |
| `app/test/design/tokens/brand_typography_test.dart` | **new** — no test covers `BrandText` today |
| `app/test/architecture/no_color_literal_test.dart` | **new** |
| `app/test/architecture/no_geometry_literal_test.dart` | **new** |
| `CLAUDE.md`, `.claude/conventions/craftsmanship.md` | PROC-6 wording corrections |

**Ordering — `f0-invariant-tests` lands first.** `app/test/architecture/` does not exist on disk;
`f0-invariant-tests` creates it, and its own block says so as a decision rather than a suggestion
(plan:1030-1031: *"It is not 'any time': it is first."*). Two scenarios here name files under that
directory. This change also **consumes** that change's `app/test/architecture/source_tree.dart`
rather than writing a second comment-stripping tree walker beside it, which makes the ordering a
code dependency and not only a sequence. See `design.md` D11.

**Blocks.** Every screen change in the document, and directly: `f0-pressable-surface`,
`f0-dashed-border`, `f0-brand-icons`, `f0-keypad`, `f0-stat-readouts`.

**Risk this closes.** R5 — prose invariants erode under agents. Two of BRD-2b's clauses stop being a
`grep` a reviewer has to remember to run.
