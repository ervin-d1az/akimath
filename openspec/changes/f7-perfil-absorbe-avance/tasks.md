# Tasks

## 1. The move

- [x] 1.1 `git mv` the progress policy to
  `features/profile/policy/history_view.dart` and its test with it. No logic
  changes — the diff should be paths.
- [x] 1.2 Delete `features/progress/`.

## 2. The screen

- [x] 2.1 `ProfileScreen` gains the stat pair and the history section, in the
  design's order. Test that the figures draw with no account, that the history
  section is absent when there is nothing true to say, and that the two halves
  fail independently.
- [x] 2.2 The pair is two cards with the design's hierarchy — white `DÍAS`
  beside yellow `RACHA`, `flex 1.3` against `flex 1`. Test the fill and that
  each names its unit.
- [x] 2.3 Aki and the bubble do not come across. Test that she appears exactly
  once and that it is inside the tile.

## 3. The route

- [x] 3.1 `ProfileRoute` takes on the day-log read and the history request,
  keeping both independent of each other and of the link.
- [x] 3.2 The `ProgressRoute` tests move onto it.

## 4. The shell

- [x] 4.1 `rootsPresentToday` becomes `{home, profile}`. `AppTab.progress`
  stays in the enum with its glyph — the design names it a home and nobody has
  drawn one.
- [x] 4.2 The registry loses its `avance` entries and gains the profile's
  states.
- [x] 4.3 `shell_tour_test.dart` walks two roots and the stack above one.

## 5. Evidence

- [x] 5.1 Tier 1 — analyze, tests, metrics, counts stated.
- [x] 5.2 Tier 1b — falsification over the history section's absence, the card
  hierarchy and the roots list.
- [x] 5.3 Tier 2 — the profile on the simulator, with and without an account.

---

## Evidence

**Tier 1** — analyze and metrics clean, **1947 tests green**, 48 screens swept at
1.0 and 1.3, 299 presses.

**Tier 1b** — 11 falsifications, 11 killed: the history heading over nothing,
both cards white, the figures waiting on the history, either card losing its
unit, the unit ceasing to agree with the count, Aki coming back loose, `Avance`
returning as a root, `progress` leaving the enum, and the two cards taking the
same width.

The last one is worth recording. It first read **survived**, and the reason was
not the code: the anchor string had the wrong indentation, so the mutation never
applied and the suite passed on unmutated code. PROC-8 exists for exactly that —
verify the mutation landed before believing the result — and the sweep script
asserts the anchor is present and unique for that reason. This one was run
through a one-off without the assertion.

Fixing the finder mattered too: the first version measured the nearest
`Container` ancestor rather than the `CandySurface`, which is a different box.

**Tier 2** — the profile on the iPhone 17 simulator, linked with three history
rows and unlinked with none.
