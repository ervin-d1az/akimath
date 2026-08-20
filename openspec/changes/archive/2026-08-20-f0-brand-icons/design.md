# Design — the icon set

## D1 · Why 21 hand-transcribed paths beat one package

The reflex is `flutter_svg`, `phosphor_flutter` or Material's own set. Three reasons none of them
lands here, in descending order of weight:

1. **DEP-1 and the audience.** Every dependency has to be checked for whether it phones home before
   it is proposed. Today the app's runtime list is three packages and none makes a network call — a
   property that holds *by construction*, which is much cheaper to defend than a property that holds
   by audit.
2. **The glyphs carry per-glyph stroke weights.** The submit arrow is 3.2, the backspace 2.6. A
   general icon set normalises stroke weight; reproducing the design's would mean overriding the
   package glyph by glyph, which is transcription with extra steps and a dependency.
3. **21 paths is small.** This is not a case where hand-rolling loses on volume.

The counter-argument worth naming: transcription can be wrong in ways a package is not. That is what
the spec's numeric assertions are for — a wrong stroke weight fails a test rather than looking
slightly off in review.

## D2 · Verbatim, not by eye

Path data is transcribed **exactly** from the design digests. Where a digest gives coordinates, those
coordinates go in. Where it does not, **the glyph waits** rather than being drawn approximately.

This is a rule about provenance, not about pixel precision. An icon redrawn by eye is a fork of the design
that nobody knows exists, and it diverges silently at the next design revision. A missing icon is
visible.

## D3 · Size is a render parameter, not a variant

The backspace glyph appears at 24 px on the item keypad and 23 px on the puzzle keypad. Those are
**one spec rendered at two sizes**, and the first scenario asserts exactly that — because the tempting
alternative is `backspace24` and `backspace23`, which is how a 21-glyph set becomes a 40-glyph set
that disagrees with itself.

Stroke weight, by contrast, **is** on the spec. It is a property of the glyph's identity in this
design, not of the moment it is drawn.

## D4 · The allowlist test is the real deliverable

`req-icon-allowlist` looks like housekeeping attached to an icon change. It is the opposite: it is the
change's most durable output.

`CLAUDE.md` says never add a dependency that collects data, and DEP-1 says check before proposing.
Both were prose. R5 in the plan names the exact failure mode — *agents erode invariants that live only
in prose* — and its early signal is a pull request touching `pubspec.yaml` when the task did not ask
for it.

A committed allowlist converts that from a review habit into a red build. **And it deliberately fails
on *any* addition, not just a data-collecting one**, because the test cannot judge whether a package
phones home; a human must, and the failure is what summons them. The second scenario requires the
failure to *name the package*, so the reviewer knows what to audit without reading a diff.

One amendment is already scheduled: `f8-motion`'s Rive. It will amend this test and carry the
phones-home audit in the same change, which is the workflow this gate exists to force.

## D5 · Where the split falls with `IconButtonTile`

`f0-pressable-surface` owns a 48×48 tile with a toggled background. This change owns the glyph inside
it. The tile never knows a path; the glyph never knows it is inside a tile.

That keeps the toggled-fill decision (`#FFD447` versus surface) in one change and the stroke weight in
another, which is right — they are revised by different people for different reasons.

## Alternatives rejected

- **`flutter_svg` plus 21 SVG assets.** A runtime dependency, an asset bundle, and a parser, to render
  geometry that is already known at compile time. It also defeats the pure-boundary gate: the geometry
  would live in a file the import graph cannot see.
- **Material Icons.** Free, present, and the wrong shapes — different stroke weights, different
  terminals, and no KenKen mark or server mark at all.
- **A code generator from the design files.** Attractive at 21 glyphs and worse at every count: it is a
  `build_runner` dependency and a CI byte-diff job, both of which ADR 0001 already rejected for the
  API client on evidence.
- **One `BrandIcon` per glyph as separate widgets.** 21 widgets agreeing about how to paint a stroke.
