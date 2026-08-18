## Why

**BRD-1 is a `CLAUDE.md` invariant with no code behind it.** Success and error must be
distinguishable by *shape*, not hue alone, because deuteranopia collapses green and coral — and
every screen in the corpus except one distinguishes them by hue alone: two 22 px circles with an
identical 3 px border, `#5ED6A4` against `#FF8A5B`.

The design already solved it on `4.5 Accesibilidad` — success is a **solid** ink outline with a
check, error is a **dashed** ink outline with an alert glyph — and then failed to propagate it.
`ARCHITECTURE.md` §6 asks for a `Verdict` type carrying no colour; this is that type.

**The encoding is always on** (D6). `4.5`'s *Modo daltonismo* toggle only adds redundancy on top —
an invariant behind a setting is not an invariant.

**Phase: F0.** The progress strip ships at F2, so this cannot wait for F7.

## What Changes

- **`app/lib/design/widgets/spec/verdict.dart`** — `Verdict` with an outline style and a glyph, and
  **no colour accessor at all**. Pure.
- **`app/lib/design/widgets/verdict_ring.dart`** — the adapter that paints one.

## Capabilities

### New Capabilities
- `verdict-encoding`: how the app says right or wrong, in a way that survives a reader who cannot
  separate the two hues.

## Impact

- **New:** `design/widgets/spec/verdict.dart`, `design/widgets/verdict_ring.dart`.
- **New tests:** `test/design/widgets/spec/verdict_test.dart`.
- Covered by the existing `design/**/spec/` pure root and both literal gates.
- **No new dependency.**

## Non-goals

- **The progress dots.** Their greyscale scenario lives in `f2-core-loop`, deliberately: naming a
  test under `features/round/` from here would be an ordering edge into a change that depends on
  this one — a cycle. This change verifies the type and its paint adapter, which is where it can
  actually go red.
- **Resolving DR-4.** `ItemTermTile`'s `unknown` state is *already* yellow + 3 px dashed + `?` on
  five of six stimulus screens, so on that widget `Verdict.wrong` cannot claim the dash without
  colliding with "still to fill". Which channel `unknown` gives up is a design decision, not a code
  one.
- **A colour-blind mode toggle.** The encoding is unconditional.

## What this builds on

- **`DashSpec` and `DashedBorderPainter`** — landed in `f0-dashed-border`. The dashed half of the
  encoding is drawn with them.
- **`BrandIcon`** — the check and alert glyphs go through the named seam.
- **`BrandColorRole`** — the adapter resolves a hue *in addition to* the shape, never instead of it.
