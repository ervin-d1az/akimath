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

- [x] 1.1 Write `app/test/design/math/spec/es_mx_number_test.dart` covering all three scenarios of
      `req-number-format`: `integer(1180)` → `1 180` with **U+202F**, `seconds(4.2, places: 1)` →
      `4,2 s`, `ratio` → `3 / 9`, and `deltaParts` returning a sign run and a digit run.
      **Check:** `flutter test` — three new failures, and the separator assertion compares code
      points, not rendered width.
      **Done.** Seen failing first — `Undefined name 'EsMxNumber'` across every call. The separator
      assertion reads `codeUnits, contains(0x202F)` and additionally forbids U+0020, because the two
      render almost identically and an equality check on a literal proves nothing a reader can see.
- [x] 1.2 Write `app/lib/design/math/spec/es_mx_number.dart` until they pass. No Flutter import.
      **Check:** `flutter test` green; `grep -c "package:flutter" es_mx_number.dart` returns 0.
      **Done.** 22 tests green; the grep returns **0**.
- [x] 1.3 Assert U+2212 across **every** entry point that can emit a negative, not only `deltaParts`.
      **Check:** the test enumerates the module's public surface and fails if a new entry point is
      added without a minus-sign assertion.
      **Done.** The module publishes `negatableEntryPoints`; the test asserts its own coverage set
      equals it, so a formatter added without a minus assertion fails rather than passing silently.
- [x] 1.4 **Widened while implementing, and worth naming rather than burying:** D8 picked U+202F for
      thousands because a plain space wraps `1 180` into `1` / `180` inside a 48 px pill at
      `textScaler` 1.3. That reasoning is not specific to thousands — the unit in `4,2 s`, the slash
      in `3 / 9` and the cross in `6 × 6` all sit in the same pills and tiles. Every space the module
      emits is therefore U+202F, asserted once over the whole surface rather than per formatter.
      **Check:** `no output can wrap mid-value` iterates all ten formatters and forbids U+0020.

## 2 · The pure layout

- [x] 2.1 ~~Add `design/math/spec/` as a declared root in
      `app/test/architecture/pure_boundary_test.dart`.~~ **Nothing to add — this task's premise was
      wrong.** `f0-invariant-tests` wrote the root as the glob `design/**/spec/`, not as a list of
      directories, so `design/math/spec/` was already inside it the moment the directory existed.
      **Check:** the gate's own report reads `design/**/spec/ → 3 files` where it read 2 before this
      change, and `no file under a pure root reaches a forbidden URI today` is green. The new module
      was covered without anyone remembering to declare it — which is the argument for a glob over a
      list, and it is worth recording because the next spec root will be free too.
- [x] 2.2 Write `app/test/design/math/spec/fraction_metrics_test.dart` asserting the three measured
      rows: 76 → (6, 58), 46 → (4, 36), 22 → (3, 26).
      **Check:** `flutter test` — three failures. Assert the pairs, not a formula (design D3).
      **Done.** Seen failing first: `Undefined name 'FractionMetrics'`.
- [x] 2.3 **Spike finding 2** — add a fourth case *between* the stated rows, and one above the
      largest. A step function passes 2.2 and is still wrong: text scaling puts the effective size
      between the rows (76 × 1.3 = 98.8), where a step serves the same 6 px bar it gives 76 and the
      bar reads too thin. Seen directly in `spike-b/scaled-1.3.png`.
      **Check:** the interpolated cases go red against a step implementation.
      **Done, and demonstrated rather than asserted.** The step function was written first and run:
      it **passes all three stated rows** and fails six other assertions. The sharpest is the
      proportion one — `Actual: 0.06072` against `Expected: within 0.0079 of 0.07895` — which is the
      23 % collapse measured off the spike capture, reproduced as a number.
      The final shape is piecewise-linear through the three measured points, clamped below 22 and
      slope-extended above 76. `max(3, round(size × 0.079))` was considered and dropped: it fits the
      three rows but rounds, which reintroduces a step between them.
- [x] 2.4 **Spike finding 1** — the parameter is the **effective** size, not the nominal one. Name it
      so in the signature and say so in the doc comment, because "size" is exactly what a caller will
      pass an unscaled value to.
      **Check:** the parameter is `effectiveSize` and the doc comment says what goes wrong if a
      caller passes a nominal value. The property is tested as the thing a user sees — the
      thickness-to-size ratio holds within 10 % across the whole 1.0–1.3 range — rather than as an
      implementation detail. The spec never sees a `TextScaler`; the adapter resolves it.
- [x] 2.5 Write `app/lib/design/math/spec/fraction_metrics.dart`.
      **Check:** green, and the pure-boundary gate now reports the root present with a non-zero count.
      **Done.** 10 tests green; the gate reports `design/**/spec/ → 4 files`; `grep -c
      "package:flutter"` returns 0. The three measured rows live in one visible table rather than in
      branches, so a reader checks them against the design without reading control flow.
- [x] 2.6 Write `app/test/design/math/spec/math_node_test.dart`: a fraction nested inside a fraction
      laying out from **injected** metrics (Darumadrop x-height 435/1000), per-token operator faces,
      the defaults when a token names none, and the absence of any inline-fraction parameter.
      **Check:** `flutter test` — failures across all four; the test passes literal metrics and uses
      no fake canvas and no golden.
      **Done.** Seen failing first (`'PlacedBox' isn't a type`). 13 tests, no canvas, no golden — the
      adapter's text measurement is injected as a `GlyphMeasure` closure and the test passes a flat
      stand-in. Two assertions earn their place beyond the scenario text: two different faces must
      produce two different axes at the same size (a module hard-coding a ratio passes everything
      else), and the recorded metric ratios are checked against the shipped TTFs so replacing a font
      file fails a test rather than shifting every fraction quietly.
- [x] 2.7 Write `app/lib/design/math/spec/math_node.dart` with `OperatorNode(face:, tone:)`.
      **Check:** green. **Nesting stops at what the spec asserts** — no general box engine (design D6).
      **Done.** 180 Flutter tests green; `design/**/spec/ → 5 files`.
      **`tone` had to be defined, because the corpus names the parameter and never enumerates it.**
      It is a role — `MathTone { ink, muted }` — and never a `Color`, following the precedent
      `Verdict` set by carrying no `.color`. Worth stating plainly: `dart:ui` is an *allowed* leaf
      under a pure root, so nothing would have stopped a `Color` living in that file, and
      `no_color_literal_test` scans `design/widgets/` and `features/`, not `design/**/spec/`. No gate
      catches this one; the discipline is the guard, and the value set widens when a digest asks.
- [x] 2.8 **Found while implementing, and it is a modelling fix rather than a bug fix.** The first
      assembly measured the numerator's ink as its baseline, which is true of a numeral and false of
      a fraction — so a nested fraction came out *shorter* than a flat one. `MathBox` now publishes
      `inkTop` and `inkBottom`, and the assembly measures from those.
      **Check:** the nested case went from `Actual: 177.08` against `greater than 203.20` to green.
      The parent no longer asks what kind of node it received, which is what makes one level of
      recursion work without becoming the general engine D6 defers.

## 3 · The adapter

- [x] 3.1 Write `app/test/design/math/math_view_test.dart`: a rendered fraction has a numerator box
      above a rule above a denominator box, and the painted output contains **no `/` glyph**.
      **Check:** `flutter test` — red.
      **Not red first, and saying so.** The widget was written before this test, which is a TDD
      miss. Rather than claim otherwise, the tests were **falsified** instead: `size: scaler.scale(size)`
      was changed to `size: size` and the proportion assertion went
      `Expected: greater than <6.0> / Actual: <6.0>` — the spike's exact defect, caught by the suite.
      Restored by checksum to `a8051ec8cf3fc678cb3b51c160426e81209517d2700699f2f0122d2e764aac93`.
- [x] 3.2 Write `app/lib/design/math/math_view.dart`, resolving real font metrics and handing them to
      the spec. All geometry decisions stay in `spec/`; this file holds none.
      **Check:** green, and `pure_boundary_test.dart` still passes — if it fails, a decision leaked
      down into the adapter.
      **Done.** The adapter does exactly three things the spec cannot: resolves the text scaler,
      measures advances with a `TextPainter`, and maps `MathFace`/`MathTone` to a family and a
      colour. Both the measurement and the painted runs use `TextScaler.noScaling`, because the
      scaler is applied once on the way in — applying it again would square it.
- [x] 3.3 Add `ExpressionRow`, `AnswerSlot` and `FractionGlyph` (`plain` variant only — the struck
      and editable-slot variants belong to their consuming changes).
      **Check:** `flutter test`; `flutter analyze --fatal-infos` clean.
      **One of the three built, and the other two are decisions rather than omissions.**
      · **`FractionGlyph` — built.** It earns a name by taking two strings where `MathView` takes a
        tree, and it has a scheduled consumer at a fixed small size (the keypad's 15 px `a/b` face,
        `f0-keypad`). Tested at that size, where the rule clamps to 3 instead of vanishing.
      · **`ExpressionRow` — not built, deliberately.** It would be exactly
        `MathView(node: RowNode(children))` and nothing else. The plan's own warning about a second
        widget that draws a 3 px outline applies to wrappers too: a name that adds no behaviour is a
        second thing to keep in agreement with the first.
      · **`AnswerSlot` — deferred to `f0-dashed-border`.** Its defining state is the *dashed* pink
        focus outline, and nothing in the repo can draw a dash yet. A solid-only stand-in shipped now
        is a widget that gets rewritten rather than extended — the same reasoning D22 used to keep
        the dash and its gate in one change.
- [x] 3.4 Confirm no colour literal and no `Offset(` literal entered the new widget files.
      **Check:** `no_color_literal_test.dart` and `no_geometry_literal_test.dart` green, both
      reporting a **higher** scanned-file count than before this change.
      **The colour gate covered the new files; the geometry gate did not, and that was a real gap.**
      Its roots were `design/widgets/` and `features/`, so `design/math/` — a widget surface, not
      artwork — was the one painted layer `BrandShape` did not govern. Added test-first: the new
      root assertion failed `Expected: length of <1> / Actual: []` before the root existed.
      Counts now: colour `lib/ minus design/tokens/ → 19 files`, geometry `design/math/ → 5 files`
      alongside `design/widgets/ → 3` and `features/ → 2`.

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
