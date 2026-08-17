# Tasks — the dashed outline

TDD throughout: each test is written and **seen failing** before the code that satisfies it.

**Ordering constraint (design D1):** the widened gate and the dash land in the same change. Do not
merge section 2 without section 4 — the gap between them is exactly the interval in which the no-blur
invariant silently stops covering the components that carry BRD-1.

## 1 · The pure segmentation

- [x] 1.1 Add `design/painting/spec/` as a declared root in
      `app/test/architecture/pure_boundary_test.dart`.
      **Check:** the gate reports the root **absent** (0 files) before 1.4 — absent, not passing.
- [x] 1.2 Write `app/test/design/painting/spec/dash_spec_test.dart`, first scenario:
      `DashSpec(on: 9, off: 9).segments(pathLength: 100)` covers the full length with the final
      segment **truncated**, never overrunning.
      **Check:** `flutter test` — red. 100 is not evenly divisible by the pattern on purpose.
- [x] 1.3 Add the second scenario: KenKen (`6 4`) → **10** segments, Killer (`2 5`) → **15**,
      locked-edge (`9 9`) → **6**, over a 100 px path, and the Killer pattern reports a round cap.
      **Check:** red. Assert the three counts, never "the lists differ" — that phrasing passes for
      any implementation that reads its arguments (design D2).
- [x] 1.4 Write `app/lib/design/painting/spec/dash_spec.dart`. It receives a length and returns
      segments; it never sees a `Path` and never calls `computeMetrics`.
      **Check:** green; pure-boundary gate now reports the root present with a non-zero count.

## 2 · The painter and `CandySurface`

- [x] 2.1 Write `app/test/design/painting/dashed_border_test.dart`, focused answer slot: border 3 px,
      `BrandColors.pink`, dashed, radius 12, and **no solid border painted**.
      **Check:** red. The "no solid border" half is what catches a dashed stroke drawn on top of a
      solid one.
- [x] 2.2 Add the cage scenario: KenKen 2.5 px pink, rx 10, inset 5; Killer rx 9, inset 6; neither
      overlapping the 1.5 px hairline beneath.
      **Check:** red. These numbers are recorded now although cages ship in F6 (design D4).
- [x] 2.3 Write `app/lib/design/painting/dashed_border_painter.dart` and add `borderDash` to
      `CandySurface`.
      **Check:** green; `flutter analyze --fatal-infos` clean; `no_geometry_literal_test.dart` and
      `no_color_literal_test.dart` both green with a **higher** scanned-file count than before.

## 3 · Confirm the gap is real before closing it

- [x] 3.1 With `borderDash` in the tree and the gate **not yet widened**, add a blurred `MaskFilter`
      to the dashed painter and run `no_blurred_shadow_test.dart`.
      **Check:** it **passes** — proving the painter is outside the gate's reach, which is the whole
      premise of D22. Record the output. Then remove the blur.
      A change that widens a gate without first demonstrating the hole is asserting D22, not showing it.

## 4 · Widen the gate — same change, not the next one

- [x] 4.1 Extend `app/test/design/no_blurred_shadow_test.dart` with the two new assertions:
      no `BackdropFilter`, and no non-zero `MaskFilter` in the pumped tree.
      **Check:** re-run 3.1's blurred painter — it now **fails**. That is the same experiment with the
      opposite result, which is the evidence this section exists to produce.
- [x] 4.2 Add the screen-count assertion: the gate reports how many screens it walked and fails at
      zero.
      **Check:** the count appears in the output and matches `screen_registry.dart`'s length.
- [x] 4.3 Confirm the six assertions all run against every registered screen.
      **Check:** `flutter test` green — four existing assertions plus two new ones.

## 5 · Evidence

- [x] 5.1 **Tier 1** — `flutter analyze --fatal-infos` clean, `flutter test` green, the new total
      written here as a number. Baseline before this change is 135.
      **Check:** the count, recorded when known.
- [x] 5.2 **Tier 1b** — the falsification is already done and recorded: tasks 3.1 and 4.1 are the same
      blur seen passing and then failing. Quote both outputs here (PROC-5).
      **Check:** two quoted results, not one claim that the gate works.
- [x] 5.3 Second falsification, on the arithmetic: change the KenKen expectation from 10 to 9 and
      confirm `dash_spec_test.dart` goes red; restore and confirm the suite returns to 5.1's count
      exactly.
      **Check:** the failing assertion quoted, and the restored count matching.
- [x] 5.4 **Tier 2** — **the slot half is done; the cage half has no subject yet.**
      · **Focused answer slot — verified on the iPhone 17, twice.**
        `openspec/changes/f2-core-loop/evidence/round-playable.png` (2026-08-16) and
        `openspec/changes/f2-onboarding-first-run/evidence/03-primer-reto.png` (2026-08-17) both show
        it on a shipped screen at real device density: `DashSpec.locked`'s `9 9` reads unmistakably as
        dashed at the drawn size, in pink, with no gap collapsing at the corners.
      · **Cage — deferred to `f6-puzzles`, stated rather than skipped (PROC-5).** `CageOutline` exists
        in `design/painting/spec/` and **no widget draws a cage**: `DashedBorderPainter` has no cage
        caller anywhere in `app/lib/`. There is nothing on a screen to photograph, so the honest
        record is a deferral with an owner rather than an open box with none — which is exactly the
        failure mode task 2.3 of `f0-verdict` just cost a day to.
      No harness was needed for the half that was done, because the answer slot ships on two screens.

---

## Build log — 2026-08-16

**Tier 1.** `flutter analyze --fatal-infos` clean, **232 Flutter tests** green (212 before this
change). Gate coverage all up: pure boundary `design/**/spec/ → 6 files`, colour `→ 24 files`,
geometry now `design/widgets/ 6 · design/math/ 5 · design/painting/ 2 · features/ 2`.

**Task 1.1 had the same wrong premise task 2.1 had in the compositor.** No root needed declaring —
`design/**/spec/` is a glob, so `design/painting/spec/` was inside it as soon as the directory
existed. Recorded rather than quietly ticked.

**Sections 3 and 4 became a permanent test rather than a transcript claim.** The plan asked for the
hole to be demonstrated before it was closed, then closed. Doing that as two throwaway runs would
have left nothing behind, so `no_blurred_shadow_test.dart` now carries both experiments:

- *the DecoratedBox walk alone cannot see a painter blur* — pumps a dashed `CandySurface`, confirms
  its `BoxDecoration.border` is **null** (the outline is not there to inspect), and shows the new
  assertion does have something to look at;
- *a painter that blurs is caught* — the same experiment with a deliberately blurred painter,
  confirming the widened assertion is not vacuous.

**How the widened assertion works, because it is not obvious.** A painter's blur exists only at the
moment of painting — it cannot be read off the widget tree. So each `CustomPaint` in the pumped tree
is run against a `Canvas` that draws nothing and keeps every `Paint` it is handed. The spy uses
`noSuchMethod` rather than overriding the handful of draw calls in use today, so a painter added
later cannot slip past by reaching for a method nobody remembered to override.

**`design/painting/` added to the geometry gate**, for the same reason `design/math/` was: it is
where a border goes when it stops being a `BoxDecoration`, and a painted outline is no less governed
by `BrandShape` than a decorated one.

**Cage geometry recorded although cages ship in F6** (design D4). `CageOutline.kenKen` and
`.killer` carry the dash, stroke, radius and inset, and the hairline-clearance assertion is
arithmetic on those figures — `inset − strokeWidth/2 > 0.75` — rather than a painted puzzle that
does not exist yet.

**Task 5.3's falsification failed to fail, and that was the most useful moment in this change.**
Changing `DashSpec.kenKenCage` from 6/4 to 6/5 left the suite **green**. The reason: the test built
its own `DashSpec(on: 6, off: 4)` and asserted the arithmetic, leaving the three named constants the
app actually uses pinned by nothing at all. The tests now assert **through the constants**, and the
same edit produces `Expected: <4> / Actual: <5.0>`. Restored to
`d4034c4c57480db0e0a16ec044246a9a7c46b305c7176fb01ab877f597f329c8`, suite back to 232.

That is the whole argument for PROC-5 in one incident: three tests that looked like they pinned the
design's dash patterns tested only that addition works.

**Task 5.4 (Tier 2) not run.** The dash has no screen yet; the answer slot that carries it is
`AnswerSlot`, which this change unblocks and `f2-core-loop` places. Stated rather than skipped
(PROC-5).
