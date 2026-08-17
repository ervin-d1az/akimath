# Tasks — the stat readouts

TDD throughout: each test is written and **seen failing** before the widget that satisfies it.

## 1 · The gate, first — it constrains everything after it

- [x] 1.1 Write `app/test/architecture/no_hue_by_comparison_test.dart`: no colour is chosen by a
      numeric comparison anywhere in `app/lib/`.
      **Check:** seen failing first against a deliberately wrong pattern, then corrected — a gate
      green from the moment it was written proves nothing (PROC-8). It must report the file count it
      scanned and fail at zero.
- [x] 1.2 State the scan's limits in the source, so they read as limits rather than being found as
      bugs: it cannot see a comparison split across statements, and it must allow a colour resolved
      from an **enum**, which is what `MasteryLevel` legitimately is.
      **Check:** a test for each limit, asserting the stated behaviour rather than leaving it to a
      reader.

## 2 · The meter

- [x] 2.1 Write `meter_layout_test.dart`: the 6 px ink marker overhangs a h14 track by ±4 and a h16
      track by ±5.
      **Check:** red. Assert both pairs, not a formula (the `f0-dashed-border` lesson — assert the
      measured rows, and assert them through the **named constants** the app uses, not through
      values the test builds itself).
- [x] 2.2 Write `MeterLayout` and `MasteryLevel` in `design/widgets/spec/`.
      **Check:** green; pure boundary up by two files.
- [x] 2.3 Write `baseline_meter_test.dart`: the constructor takes a `MasteryLevel` and **no**
      parameter of type `Color`.
      **Check:** red, then green.

## 3 · The tiles, the pill and the chip

- [x] 3.1 `stat_tile_test.dart` — the three variants' radius, shadow and value size, plus the delta
      rendered as two runs through `EsMxNumber.deltaParts`.
      **Check:** red. The delta assertion must confirm the sign is a separate run, not a substring.
- [x] 3.2 `stat_pill_test.dart` — both sizes, and the two screens that forced K8: `hero` at height 56
      on yellow, and at height 64 with the default background.
      **Check:** red.
- [x] 3.3 Write the four widgets on `PressableSurface` where they are pressable.
      **Check:** green; analyze clean; colour and geometry gates green with higher scanned counts.

## 4 · Evidence

- [x] 4.1 **Tier 1** — analyze clean, suite green, the new total as a number.
- [x] 4.2 **Tier 1b** — falsify twice, because two different claims are being made: change one meter
      overhang and confirm `meter_layout_test` goes red, and write a `pct >= 90 ? green : pink` into
      a widget and confirm the new gate catches it. Restore both by checksum.
- [x] 4.3 **Tier 2** — applies: the tiles and a meter on the iPhone 17 at `textScaler` 1.0 and 1.3.
      A readout that fits at 1.0 and clips at 1.3 is the defect this change is most likely to ship,
      and the compositor already produced one of exactly that shape.

---

## Build log — 2026-08-16

**Tier 1.** analyze clean, **431 Flutter tests** green (394 before). Gates: pure boundary
`design/**/spec/ → 12 files`, colour `→ 45 files`, and the new
`no hue by comparison · lib/ minus design/tokens/ → 45 files`.

**Tier 1b — two falsifications, because two claims are made.**

- *The overhang is a function of track height.* Replacing the derivation with a constant `4` gave
  `Expected: <5> / Actual: <4.0>`, `Expected: <1.5> / Actual: <4.0>` and
  `Expected: <26> / Actual: <24.0>` — three rows at once, because the rule is asserted over
  **every** track rather than the two the design measured.
- *No hue is chosen by comparison.* Adding `fraction >= 0.9 ? success : accent` to `BaselineMeter`
  put the new gate red with the offending line quoted.

**And the restore walked straight into PROC-8.** `git checkout -- <file>` failed on both with
`pathspec ... did not match any file(s) known to git` — they are **new files**, untracked, so git had
nothing to restore from and the mutations were still sitting in the tree. The checksums recorded
before the mutation are what caught it. Restored by hand and verified back to
`322370ea…` and `8c2ec016…`. This is the rule's own worst case, reached by reflex, three commits
after correcting three agent files that taught the same reflex.

**Tier 2 — `evidence/readouts-both-scales.png`.** Tiles, both pill sizes, the chip and three meters
at `textScaler` 1.0 **and** 1.3 on the iPhone 17. No overflow, no clipping, and no exception in the
run log. The specific thing that was worth looking at: **the meters do not grow with the text
scaler and should not** — a track height is geometry, not type — while the tiles around them do, and
the two still sit together without collision at 1.3.

**`MasteryLevel` has four values and every one has a covered adapter arm.** After the
`MathTone.muted` finding — an enum a test pinned while the arm behind one value was unreachable —
the level→colour mapping is exercised for all four, and the assertion is that the four resolve to
**four distinct** hues rather than merely that the mapping exists. The values themselves are the
skill map's own legend, not an invention; their producer arrives with `f5-skill-map`.

**Task 1.2's stated limits are tested, not just written.** The gate allows a colour resolved from an
enum (that is the remedy), allows `verdict == null ? focus : error` (equality is not a threshold),
and allows a generic type argument near a colour — `<` and `>` are generics far more often than
comparisons, and a naive pattern reports every `List<Widget>` in the file.
