# Design — the dashed outline

## D1 · Why the dash and the widened gate are one change (D22)

This is the load-bearing decision, and it is a sequencing argument rather than a code one.

`no_blurred_shadow_test.dart` walks `DecoratedBox` and `PhysicalModel`. Those are the two places a
border can live *today*. `CandySurface.borderDash` moves a border into a `CustomPainter` — and a
painter is invisible to that walk.

So if the dash lands in one merge and the widened gate in the next, then for the whole interval
between them the no-blur invariant **silently stops covering** the answer slot, `4.8`'s placeholders,
the locked map node, `VerdictChip`, every cage and Sopa's capsule. Not weakened — *absent*, on exactly
the components that carry BRD-1's shape encoding.

A gate that quietly stops covering things is worse than one that was never written, because the green
build now asserts something false. The two land together, and `f0-invariant-tests` is a hard
dependency rather than a courtesy.

## D2 · Segment counts, not "different segment lists"

The second scenario asserts that the three patterns produce **10, 15 and 6** segments over a 100 px
path.

The tempting phrasing — *"the three patterns produce different segment lists"* — is true of any
implementation that reads its own arguments. It can never go red. It is a test-shaped object that
tests nothing, and the plan calls this out explicitly rather than leaving it to review.

Same reasoning drives the first scenario: the interesting case is a pattern that does **not** divide
the perimeter evenly, because that is where an implementation either truncates the final segment or
overruns the path. `9 9` over 100 is deliberately not a clean division.

## D3 · The arithmetic is pure and the stroking is not

`DashSpec.segments(pathLength:)` takes a number and returns numbers. It never sees a `Path`, never
calls `computeMetrics`, never touches a `Canvas`.

The painter does all three: it measures the rounded rectangle, asks the spec how to cut that length,
and strokes the pieces. **Every decision is above the line; every effect is below it.** That is what
lets `dash_spec_test.dart` assert three exact counts with no fake canvas — which is the PURE-1 test
verbatim: proving the decision correct must not require faking a canvas.

## D4 · Cage insets are specified here although cages ship in F6

`req-dashed-outline`'s second scenario pins the KenKen cage at 2.5 px, rx 10, inset 5, and the Killer
at rx 9, inset 6, neither overlapping the 1.5 px hairline beneath.

Cages are `f6-puzzles`, phases away. Specifying them now looks premature and is not: **the insets are
a property of the outline geometry**, and they are in the design digests today. Recording them where
the geometry lives means F6 consumes a tested number rather than re-deriving it from a mock, and the
"neither overlaps the hairline" assertion is the kind of one-pixel relationship that is obvious in a
digest and invisible six phases later.

The dash carries no *meaning* here — solid-versus-dashed as a verdict is `f0-verdict`. This change
draws; it does not interpret.

## D5 · What the widened gate cannot do

`req-no-blur-painters` asserts no `BackdropFilter` and no non-zero `MaskFilter` **in the pumped tree**.
That is real coverage and it is not total: a painter that computes a blur some other way, or a screen
never added to `screen_registry.dart`, escapes it.

The second scenario is the guard against the second failure — the gate reports how many screens it
walked and fails at zero — which is the same vacuous-gate protection `f0-invariant-tests` already
established after a registry-driven test was found capable of passing over nothing.

**`CLAUDE.md`'s Never list still carries `BackdropFilter` as intent the reviewer enforces by reading.**
This change makes it a red build for registered screens; it does not make the prose redundant.

## Alternatives rejected

- **`path_drawing` or a similar dashing package.** A runtime dependency for arithmetic that is ten
  lines, on a project whose dependency floor is a stated constraint (DEP-1).
- **Dashing with a `PathEffect`-style shader.** Not available in Flutter's public painting API, and
  the workarounds put the segmentation somewhere no pure test can reach it.
- **Landing the gate widening in `f0-invariant-tests` instead.** Rejected under D1 — it is the same
  gap in the other direction: the gate would cover painters before any painter existed, then the dash
  would arrive in a change that never had to prove it stayed covered.
- **Asserting the dash with a golden image.** Goldens go red on a font or platform bump and say nothing
  about which segment moved. Counts and insets are asserted numerically.
