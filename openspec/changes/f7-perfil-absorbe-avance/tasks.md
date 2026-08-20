# Tasks

## 1. The move

- [ ] 1.1 `git mv` the progress policy to
  `features/profile/policy/history_view.dart` and its test with it. No logic
  changes — the diff should be paths.
- [ ] 1.2 Delete `features/progress/`.

## 2. The screen

- [ ] 2.1 `ProfileScreen` gains the stat pair and the history section, in the
  design's order. Test that the figures draw with no account, that the history
  section is absent when there is nothing true to say, and that the two halves
  fail independently.
- [ ] 2.2 The pair is two cards with the design's hierarchy — white `DÍAS`
  beside yellow `RACHA`, `flex 1.3` against `flex 1`. Test the fill and that
  each names its unit.
- [ ] 2.3 Aki and the bubble do not come across. Test that she appears exactly
  once and that it is inside the tile.

## 3. The route

- [ ] 3.1 `ProfileRoute` takes on the day-log read and the history request,
  keeping both independent of each other and of the link.
- [ ] 3.2 The `ProgressRoute` tests move onto it.

## 4. The shell

- [ ] 4.1 `rootsPresentToday` becomes `{home, profile}`. `AppTab.progress`
  stays in the enum with its glyph — the design names it a home and nobody has
  drawn one.
- [ ] 4.2 The registry loses its `avance` entries and gains the profile's
  states.
- [ ] 4.3 `shell_tour_test.dart` walks two roots and the stack above one.

## 5. Evidence

- [ ] 5.1 Tier 1 — analyze, tests, metrics, counts stated.
- [ ] 5.2 Tier 1b — falsification over the history section's absence, the card
  hierarchy and the roots list.
- [ ] 5.3 Tier 2 — the profile on the simulator, with and without an account.
