# Tasks — the reduced home

- [x] 1.1 `HomeScreen`, test-first: the five elements F2 can source, and the four it must not show.
      **Done.** 8 tests. The absence checks assert the *reason*, not just the fact — the rating one
      forbids the words as well as a figure, because a greyed-out pill is precisely what F2 must not
      show.
- [x] 1.2 The preview goes through the real compositor (design D1).
      **Done.** `MathView` and `nodeFor`, so the card cannot drift from the item — and it inherited
      the clipped-`=` fix for free.
- [x] 1.3 `HomeRoute` — pack, streak, and the series pushed as a full-screen session.
      **Done.** 7 tests. This is `fullScreenSession`'s first real caller: until now declared rule 1
      was enforced by a test and by nothing a player could reach.
- [x] 1.4 Skeletons while the pack loads.
      **Done.** Shaped like the home, so nothing jumps. The test had to **advance the timer
      explicitly** — `pumpAndSettle` waits for frames, not for a pending `Future.delayed`, so the
      first version asserted the skeletons were gone while they were still there.
- [x] 1.5 `main.dart` opens on the home; register it in the screen registry.
      **Done, inside its shell.** Registered bare it failed `screen_text_style_test` for want of a
      `Material` ancestor — correctly, because a screen registered in a shape the app never builds
      is a gate checking something nobody ships.

## 2 · A defect the device found

- [x] 2.1 **`StatPill` stretched to fill the width it was offered.** On the home the streak pill
      spanned the entire screen. The cause is `Container.alignment` expanding to its constraints —
      **the exact trap `CandySurface` documents in its own source**, walked into by a widget written
      three commits later.
      **Fixed** by centring with an `Align` carrying a width factor, the same way `CandySurface`
      already solves it. Two tests: a pill in a stretching column stays narrow (`Actual: <390.0>`
      before), and a wider label makes a wider pill (`Actual: <800.0>` before — it filled whatever it
      was given either way).
      Both evidence screenshots are committed, because the difference between them is the finding.

## 3 · Evidence

- [x] 3.1 **Tier 1** — analyze clean, **513 Flutter tests** green (489 before).
- [x] 3.2 **Tier 1b** — the pill defect is the falsification: the tests were written against the
      broken widget and failed with the measured widths above, then passed against the fix.
- [x] 3.3 **Tier 2** — `evidence/home.png`, iPhone 17: Aki and the bubble, the composed
      `7 + 6 =` preview, the streak pill hugging its content, and one green button.
      `evidence/home-stretched-pill.png` is the same screen before 2.1.

## 4 · What this does not close

- **`DayLogStore`** — the streak reads zero on a fresh launch because nothing persists the days yet.
- **Whether a zero streak should show at all** — a design question, not this change's to take.
- **`f2-onboarding-first-run`** — `0.2 → 0.3 → home` is a separate change.
