## Why

BRD-1 says success and error must be distinguishable by **shape**, not only by hue, because
deuteranopia collapses green and coral. The shape that carries it is a **dashed outline** — solid for
a right answer, dashed for a wrong one — and nothing in `app/lib/` can draw one.

It is not one component's problem. The dash appears on the focused answer slot, the verdict chip,
`4.8`'s empty-state placeholders, locked map nodes, every KenKen and Killer cage, and Sopa's capsule.

**And there is a second reason this change exists in this shape.** `no_blurred_shadow_test.dart`
walks `DecoratedBox` and `PhysicalModel` only. The moment a border moves into a `CustomPainter`, that
surface **leaves the gate's reach** — and a dashed border is precisely what moves it. Landing the dash
and the widened gate in separate merges means the no-blur invariant silently stops covering the very
components that carry BRD-1, for as long as the gap lasts. So they land together (§5.3 D22).

**Phase: F0** (`ARCHITECTURE.md` §9), and it depends on `f0-invariant-tests` because it amends that
change's gate.

## What Changes

- **`app/lib/design/painting/spec/dash_spec.dart`** — dash segmentation as pure data. Given a pattern
  and a path length, it returns segments. No `Canvas`.
- **`app/lib/design/painting/dashed_border_painter.dart`** — the adapter that strokes them around a
  rounded rectangle.
- **`CandySurface` gains `borderDash`**, which is the API the consuming screens use.
- **`no_blurred_shadow_test.dart` is widened** to assert the absence of `BackdropFilter` and of any
  non-zero `MaskFilter` in the pumped tree — two assertions on top of the four it makes today.

## Capabilities

### New Capabilities
- `dashed-outline`: how a dashed border is segmented and painted, and the guarantee that moving a
  border into a painter does not escape the no-blur invariant.

### Modified Capabilities

None at the spec level. `no_blurred_shadow_test.dart` is a test this change extends, not a published
requirement whose behaviour changes — `req-no-blur-painters` is added here rather than modifying an
existing requirement, per §5.3 D22.

## Impact

- **New:** `app/lib/design/painting/spec/dash_spec.dart`,
  `app/lib/design/painting/dashed_border_painter.dart`.
- **Modified:** `app/lib/design/widgets/candy_surface.dart` gains `borderDash`;
  `app/test/design/no_blurred_shadow_test.dart` gains two assertions.
- **New tests:** `app/test/design/painting/spec/dash_spec_test.dart`,
  `app/test/design/painting/dashed_border_test.dart`.
- **`app/lib/design/painting/spec/` becomes a declared pure root** in `pure_boundary_test.dart`.
- **No new dependency.** Dashing is arithmetic over `Path.computeMetrics`, and the arithmetic half
  does not even touch that.
- **Every screen already registered** in `app/test/design/screen_registry.dart` is re-checked by the
  widened gate on the first run.

## Non-goals

- **The verdict encoding itself.** Solid-versus-dashed as a *meaning* is `f0-verdict`, which depends
  on this change. Here the dash is geometry with no semantics attached.
- **Puzzle cages as a feature.** `f6-puzzles` draws them; this change supplies the outline and asserts
  the two cage insets so the numbers exist before the consumer does.
- **Animating a dash.** No marching ants. Motion is F8.
- **Dashing arbitrary paths.** Rounded rectangles are what the corpus uses.

## What this builds on

- **`app/test/design/no_blurred_shadow_test.dart`** — landed in `f0-invariant-tests`. It already
  asserts four things across every registered screen; this change makes it six.
- **`app/test/design/screen_registry.dart`** — the single list both the no-blur gate and the overflow
  gate read, so widening the gate covers every screen automatically.
- **`app/lib/design/tokens/`** — landed in `f0-token-scale`; widths, radii and colours are read from
  it, never typed.
- **`app/lib/design/brand/spec/`** versus its painter — the PURE-1 precedent the dash spec follows.
