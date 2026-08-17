# Tasks — the math compositor

TDD throughout: every test below is **written and seen failing** before the code that satisfies it.
Task 0 is a spike and is the exception — it produces a decision, not a committed module.

## 0 · Spike B, before anything else

- [x] 0.1 Build the ugliest expression in v1 — the worst case the corpus contains, not a clean
      `1/2` — at 76 px with the 3 px outline applied, and look at it on a device.
      **Check:** a screenshot in the change directory and a written verdict: legible or not. Two days
      is the budget (design D1).
      **Done 2026-08-16, iPhone 17 simulator.** `spike-b/findings.md`, with `baseline-1.0.png` and
      `scaled-1.3.png`. Three cases rendered inside a 3 px-outlined card: the dense real expression
      (`3/4 + 2/5 =` with a focused slot), the nested-fraction stress case, and the three measured
      sizes. **All legible.** The outline was never the problem — at 76 px Darumadrop is not thin and
      the card's padding carries the 3 px stroke clear without iteration.
- [x] 0.2 If it is not legible, record which of numeral size, bar thickness or outline width gave
      first, and **stop** — the next step is a design conversation, not more spike.
      **Check:** either a one-line "criterion met" note, or a written finding naming the number that
      has to move.
      **Criterion met.** 76 px stands; no numeral size, bar thickness or outline width has to move.
      The spike found two layout defects instead, both folded into the tasks below rather than left
      in the findings file: the bar must derive from the **effective** (text-scaled) size, and the
      three measured rows need a curve through them rather than a step function.
- [x] 0.3 Delete the spike. It is throwaway; nothing below imports it.
      **Check:** `git status` clean of spike files before task 1 starts.
      **Done.** `lib/spike_b.dart` removed; `lib/main.dart` restored and verified by checksum back to
      `fe251eb63266fea4d5254e5e37382275a92bddae1101d8606cca80aac5128800` (`diff -q` IDENTICAL), suite
      back to **135** with `flutter analyze --fatal-infos` clean. Checksum rather than `git diff`,
      which is blind to an untracked file (PROC-8).

**Verified while spiking, worth having in one place:** the plan's font metrics are correct, read from
the shipped TTFs rather than from the document — Darumadrop `OS/2.sxHeight` 435/1000, Plus Jakarta
536/1000. Cap heights, which the plan never recorded and bar placement needs: **590** and **745**.

## 1 · `EsMxNumber` — the smallest piece, and the one every screen needs

- [ ] 1.1 Write `app/test/design/math/spec/es_mx_number_test.dart` covering all three scenarios of
      `req-number-format`: `integer(1180)` → `1 180` with **U+202F**, `seconds(4.2, places: 1)` →
      `4,2 s`, `ratio` → `3 / 9`, and `deltaParts` returning a sign run and a digit run.
      **Check:** `flutter test` — three new failures, and the separator assertion compares code
      points, not rendered width.
- [ ] 1.2 Write `app/lib/design/math/spec/es_mx_number.dart` until they pass. No Flutter import.
      **Check:** `flutter test` green; `grep -c "package:flutter" es_mx_number.dart` returns 0.
- [ ] 1.3 Assert U+2212 across **every** entry point that can emit a negative, not only `deltaParts`.
      **Check:** the test enumerates the module's public surface and fails if a new entry point is
      added without a minus-sign assertion.

## 2 · The pure layout

- [ ] 2.1 Add `design/math/spec/` as a declared root in
      `app/test/architecture/pure_boundary_test.dart`.
      **Check:** the gate reports the root **absent** (0 files) before task 2.5 — absent, not passing.
      That distinction is the point of `f0-invariant-tests`.
- [ ] 2.2 Write `app/test/design/math/spec/fraction_metrics_test.dart` asserting the three measured
      rows: 76 → (6, 58), 46 → (4, 36), 22 → (3, 26).
      **Check:** `flutter test` — three failures. Assert the pairs, not a formula (design D3).
- [ ] 2.3 **Spike finding 2** — add a fourth case *between* the stated rows, and one above the
      largest. A step function passes 2.2 and is still wrong: text scaling puts the effective size
      between the rows (76 × 1.3 = 98.8), where a step serves the same 6 px bar it gives 76 and the
      bar reads too thin. Seen directly in `spike-b/scaled-1.3.png`.
      **Check:** the interpolated cases go red against a step implementation. Thickness fits
      `max(3, round(size × 0.079))` on all three stated rows; minimum bar width fits no single ratio
      (58/76 = 0.763 against 36/46 = 0.783), so interpolate between the measured points and clamp
      outside them rather than inventing a constant that moves a number the design measured.
- [ ] 2.4 **Spike finding 1** — the parameter is the **effective** size, not the nominal one. Name it
      so in the signature and say so in the doc comment, because "size" is exactly what a caller will
      pass an unscaled value to.
      **Check:** a test passing a nominal 76 with a 1.3 scaler resolves 98.8 and gets the thicker bar.
      The adapter resolves `MediaQuery.textScaler`; the spec receives a number and stays pure.
- [ ] 2.5 Write `app/lib/design/math/spec/fraction_metrics.dart`.
      **Check:** green, and the pure-boundary gate now reports the root present with a non-zero count.
- [ ] 2.6 Write `app/test/design/math/spec/math_node_test.dart`: a fraction nested inside a fraction
      laying out from **injected** metrics (Darumadrop x-height 435/1000), per-token operator faces,
      the defaults when a token names none, and the absence of any inline-fraction parameter.
      **Check:** `flutter test` — failures across all four; the test passes literal metrics and uses
      no fake canvas and no golden.
- [ ] 2.7 Write `app/lib/design/math/spec/math_node.dart` with `OperatorNode(face:, tone:)`.
      **Check:** green. **Nesting stops at what the spec asserts** — no general box engine (design D6).

## 3 · The adapter

- [ ] 3.1 Write `app/test/design/math/math_view_test.dart`: a rendered fraction has a numerator box
      above a rule above a denominator box, and the painted output contains **no `/` glyph**.
      **Check:** `flutter test` — red.
- [ ] 3.2 Write `app/lib/design/math/math_view.dart`, resolving real font metrics and handing them to
      the spec. All geometry decisions stay in `spec/`; this file holds none.
      **Check:** green, and `pure_boundary_test.dart` still passes — if it fails, a decision leaked
      down into the adapter.
- [ ] 3.3 Add `ExpressionRow`, `AnswerSlot` and `FractionGlyph` (`plain` variant only — the struck
      and editable-slot variants belong to their consuming changes).
      **Check:** `flutter test`; `flutter analyze --fatal-infos` clean.
- [ ] 3.4 Confirm no colour literal and no `Offset(` literal entered the new widget files.
      **Check:** `no_color_literal_test.dart` and `no_geometry_literal_test.dart` green, both
      reporting a **higher** scanned-file count than before this change.

## 4 · Evidence

- [ ] 4.1 **Tier 1** — `flutter analyze --fatal-infos` clean and `flutter test` green, with the new
      total stated as a number, not as "all passing".
      **Check:** the count, written here when it is known.
- [ ] 4.2 **Tier 1b** — no Dart mutation harness is configured, so falsify instead: break one bar
      thickness from 6 to 5 and confirm `fraction_metrics_test.dart` goes red; restore and confirm
      the suite returns to its stated count. PROC-5's mechanism, which edits versioned code and is
      not optional.
      **Check:** the failing assertion quoted, and the restored count matching 4.1 exactly.
- [ ] 4.3 **Tier 2** — this change is visual, so it **does apply**. The spike already answered the
      outline question, so this pass answers what the spike could not: render the worst-case
      expression through the **real** compositor at `textScaler` 1.0 **and** 1.3 and confirm the bar
      holds its proportion at both — that is the defect finding 1 names, and a spike screenshot is
      not evidence that the implementation fixed it.
      **Check:** a screenshot, and confirmation that `main.dart` is restored afterwards by checksum
      rather than by `git diff` — the untracked-file trap PROC-8 records.
