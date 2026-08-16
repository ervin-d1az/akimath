# Tasks — the math compositor

TDD throughout: every test below is **written and seen failing** before the code that satisfies it.
Task 0 is a spike and is the exception — it produces a decision, not a committed module.

## 0 · Spike B, before anything else

- [ ] 0.1 Build the ugliest expression in v1 — the worst case the corpus contains, not a clean
      `1/2` — at 76 px with the 3 px outline applied, and look at it on a device.
      **Check:** a screenshot in the change directory and a written verdict: legible or not. Two days
      is the budget (design D1).
- [ ] 0.2 If it is not legible, record which of numeral size, bar thickness or outline width gave
      first, and **stop** — the next step is a design conversation, not more spike.
      **Check:** either a one-line "criterion met" note, or a written finding naming the number that
      has to move.
- [ ] 0.3 Delete the spike. It is throwaway; nothing below imports it.
      **Check:** `git status` clean of spike files before task 1 starts.

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
      **Check:** the gate reports the root **absent** (0 files) before task 2.3 — absent, not passing.
      That distinction is the point of `f0-invariant-tests`.
- [ ] 2.2 Write `app/test/design/math/spec/fraction_metrics_test.dart` asserting the three measured
      rows: 76 → (6, 58), 46 → (4, 36), 22 → (3, 26).
      **Check:** `flutter test` — three failures. Assert the pairs, not a formula (design D3).
- [ ] 2.3 Write `app/lib/design/math/spec/fraction_metrics.dart`.
      **Check:** green, and the pure-boundary gate now reports the root present with a non-zero count.
- [ ] 2.4 Write `app/test/design/math/spec/math_node_test.dart`: a fraction nested inside a fraction
      laying out from **injected** metrics (Darumadrop x-height 435/1000), per-token operator faces,
      the defaults when a token names none, and the absence of any inline-fraction parameter.
      **Check:** `flutter test` — failures across all four; the test passes literal metrics and uses
      no fake canvas and no golden.
- [ ] 2.5 Write `app/lib/design/math/spec/math_node.dart` with `OperatorNode(face:, tone:)`.
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
- [ ] 4.3 **Tier 2** — this change is visual, so it **does apply**: render the worst-case expression
      on the iPhone 17 simulator and confirm the outline reads at 76 px.
      **Check:** a screenshot, and confirmation that `main.dart` is restored afterwards by checksum
      rather than by `git diff` — the untracked-file trap PROC-8 records.
