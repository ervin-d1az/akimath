# Tasks — the dashed outline

TDD throughout: each test is written and **seen failing** before the code that satisfies it.

**Ordering constraint (design D1):** the widened gate and the dash land in the same change. Do not
merge section 2 without section 4 — the gap between them is exactly the interval in which the no-blur
invariant silently stops covering the components that carry BRD-1.

## 1 · The pure segmentation

- [ ] 1.1 Add `design/painting/spec/` as a declared root in
      `app/test/architecture/pure_boundary_test.dart`.
      **Check:** the gate reports the root **absent** (0 files) before 1.4 — absent, not passing.
- [ ] 1.2 Write `app/test/design/painting/spec/dash_spec_test.dart`, first scenario:
      `DashSpec(on: 9, off: 9).segments(pathLength: 100)` covers the full length with the final
      segment **truncated**, never overrunning.
      **Check:** `flutter test` — red. 100 is not evenly divisible by the pattern on purpose.
- [ ] 1.3 Add the second scenario: KenKen (`6 4`) → **10** segments, Killer (`2 5`) → **15**,
      locked-edge (`9 9`) → **6**, over a 100 px path, and the Killer pattern reports a round cap.
      **Check:** red. Assert the three counts, never "the lists differ" — that phrasing passes for
      any implementation that reads its arguments (design D2).
- [ ] 1.4 Write `app/lib/design/painting/spec/dash_spec.dart`. It receives a length and returns
      segments; it never sees a `Path` and never calls `computeMetrics`.
      **Check:** green; pure-boundary gate now reports the root present with a non-zero count.

## 2 · The painter and `CandySurface`

- [ ] 2.1 Write `app/test/design/painting/dashed_border_test.dart`, focused answer slot: border 3 px,
      `BrandColors.pink`, dashed, radius 12, and **no solid border painted**.
      **Check:** red. The "no solid border" half is what catches a dashed stroke drawn on top of a
      solid one.
- [ ] 2.2 Add the cage scenario: KenKen 2.5 px pink, rx 10, inset 5; Killer rx 9, inset 6; neither
      overlapping the 1.5 px hairline beneath.
      **Check:** red. These numbers are recorded now although cages ship in F6 (design D4).
- [ ] 2.3 Write `app/lib/design/painting/dashed_border_painter.dart` and add `borderDash` to
      `CandySurface`.
      **Check:** green; `flutter analyze --fatal-infos` clean; `no_geometry_literal_test.dart` and
      `no_color_literal_test.dart` both green with a **higher** scanned-file count than before.

## 3 · Confirm the gap is real before closing it

- [ ] 3.1 With `borderDash` in the tree and the gate **not yet widened**, add a blurred `MaskFilter`
      to the dashed painter and run `no_blurred_shadow_test.dart`.
      **Check:** it **passes** — proving the painter is outside the gate's reach, which is the whole
      premise of D22. Record the output. Then remove the blur.
      A change that widens a gate without first demonstrating the hole is asserting D22, not showing it.

## 4 · Widen the gate — same change, not the next one

- [ ] 4.1 Extend `app/test/design/no_blurred_shadow_test.dart` with the two new assertions:
      no `BackdropFilter`, and no non-zero `MaskFilter` in the pumped tree.
      **Check:** re-run 3.1's blurred painter — it now **fails**. That is the same experiment with the
      opposite result, which is the evidence this section exists to produce.
- [ ] 4.2 Add the screen-count assertion: the gate reports how many screens it walked and fails at
      zero.
      **Check:** the count appears in the output and matches `screen_registry.dart`'s length.
- [ ] 4.3 Confirm the six assertions all run against every registered screen.
      **Check:** `flutter test` green — four existing assertions plus two new ones.

## 5 · Evidence

- [ ] 5.1 **Tier 1** — `flutter analyze --fatal-infos` clean, `flutter test` green, the new total
      written here as a number. Baseline before this change is 135.
      **Check:** the count, recorded when known.
- [ ] 5.2 **Tier 1b** — the falsification is already done and recorded: tasks 3.1 and 4.1 are the same
      blur seen passing and then failing. Quote both outputs here (PROC-5).
      **Check:** two quoted results, not one claim that the gate works.
- [ ] 5.3 Second falsification, on the arithmetic: change the KenKen expectation from 10 to 9 and
      confirm `dash_spec_test.dart` goes red; restore and confirm the suite returns to 5.1's count
      exactly.
      **Check:** the failing assertion quoted, and the restored count matching.
- [ ] 5.4 **Tier 2** — applies: render a focused answer slot and a cage on the iPhone 17 simulator and
      confirm the dash reads as dashed at the drawn size, and that the cage outline does not sit on
      the hairline.
      **Check:** a screenshot, and `main.dart` restored afterwards **by checksum** — `git diff` is
      blind to an untracked harness file (PROC-8).
