## 1. Stop the home crashing on the day's item

- [x] 1.1 Red → green: a home whose preview is a number series renders it instead of throwing.
- [x] 1.2 Extract the round's stimulus dispatch so the home and the round draw a family the same
      way, and the sealed switch lives once (design D5).

## 2. The week strip

- [x] 2.1 Red → green: a pure `weekMarks(attemptDays, today)` returning seven marks ending on today,
      each played or not.
- [x] 2.2 Red → green: the boundaries — nothing played, every day played, a gap in the middle, a
      streak longer than seven days, and a day recorded in the future.
- [x] 2.3 Red → green: the strip widget draws seven marks, and played differs from unplayed by shape
      as well as fill (BRD-1).

## 3. The family row

- [x] 3.1 Red → green: a pure `familiesOf(plan)` naming each family in the order the series serves.
- [x] 3.2 Red → green: the row draws one chip per family and reflows rather than overflowing.
- [x] 3.3 Red → green: the row and the series that is actually started agree.

## 4. The home, recomposed

- [x] 4.1 Red → green: the home renders both new bands with the streak labelled.
- [x] 4.2 The home scrolls, and the CTA is above the fold at textScaler 1.0 (design D2).
- [x] 4.3 Register the recomposed home and keep `screen_overflow_test` green at 1.0 and 1.3.

## 5. Preferences

- [x] 5.1 Red → green: the screen shows days played and the streak, from local stores only.
- [x] 5.2 Red → green: the `Acierto` / `Se torció` legend, differing by shape, with copy that does
      not scold.
- [x] 5.3 Red → green: no rating, accuracy, mean time or history appears, and none of the four
      deferred toggles is drawn.
- [x] 5.4 Register it under the design gates.

## 6. The bar

- [x] 6.1 Red → green: the bar widget — two tabs, selection marked by shape, every target at least
      `BrandShape.minTouchTarget`.
- [x] 6.2 Red → green: `AppShell` draws it when `visibleTabs` returns two and not when it returns
      none, and the builder is not called in the second case.
- [x] 6.3 Add `AppTab.profile` to `rootsPresentToday` and wire the two roots together.

## 7. The splash

- [x] 7.1 Red → green: the app opens on the brand-green splash while stored state loads, and leaves
      it when that resolves.
- [x] 7.2 Red → green: no splash remains once startup completes.

## 8. Evidence

- [ ] 8.1 Tier 1: `flutter analyze --fatal-infos` and `flutter test` green, counts stated.
- [ ] 8.2 Tier 1b: falsification matrix for the new pure policies and the shape-not-hue pairs.
- [ ] 8.3 Tier 2: every new and changed screen on the simulator, with the navigation exercised.
