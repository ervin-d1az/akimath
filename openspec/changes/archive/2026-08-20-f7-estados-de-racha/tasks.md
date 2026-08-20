# Tasks

## 1. The policy

- [x] 1.1 `features/home/policy/streak_state.dart` (PURE) — `StreakState`
  (`none`, `steady`, `atRisk`, `broken`), `atRiskFrom`, and `streakStateFor`.
  Test first: the six scenarios in the delta spec, including the day-after-the-
  moment normalisation and the early-morning case.
- [x] 1.2 `hoursLeftToday` in the same file — a `Duration` to the next local
  midnight, by component arithmetic. Test the 20:14 case, the one-minute-before
  boundary, and a 23-hour day.
- [x] 1.3 `features/home/policy/broken_run.dart` (PURE) — `brokenRunLength` and
  `dayOfNewRun`. Test that `streakLength` reads 0 where `dayOfNewRun` reads 1,
  so the two quantities are pinned apart by a test and not only by a comment.

## 2. The pieces

- [x] 2.1 `flame` — **already named**, with a stand-in face like every other
  glyph. Transcribing the verbatim path data is `f0-brand-icons`' whole job and
  it covers fourteen icons, not one; doing it here would be a fork of that
  change. It is unblocked now that the design digests are reachable.
- [x] 2.2 `design/widgets/streak_badge.dart` — yellow, outlined, `shadowButton`,
  flame + numeral + label.
- [x] 2.3 `design/widgets/before_after_counters.dart` — muted/flat past against
  yellow/raised present, with the arrow between. Test that the past box carries
  **no** shadow, because that contrast is the point and it is the thing a later
  tidy-up would "fix".

## 3. The screens

- [x] 3.1 `features/states/ui/streak_at_risk_screen.dart` — `CenteredStateView`
  with the badge in `content`, the countdown chip, and both actions.
- [x] 3.2 `features/states/ui/streak_lost_screen.dart` — the counters in
  `content`, the reassurance card, one action, and **no rating figure**.
- [x] 3.3 Register both in `test/design/screen_registry.dart` and run
  `screen_overflow_test` at 1.3 before the layout is called done (D8).

## 4. Reachability

- [x] 4.1 `features/states/data/streak_notice_store.dart` — the once-a-day
  record for `4.13`, same shape as `OnboardingStore`.
- [x] 4.2 **`HomeRoute`, not `FirstRunGate`** — a correction to D5 found while
  building it. The gate reads one boolean and knows nothing about a `DayLog`, so
  putting the decision there would add a second reader of it; worse, `Resolver
  uno ahora` has to start a series, and the gate has no pack, no cursor and no
  navigator. `HomeRoute` has all three, so the notice is **pushed over** the
  home through the same `fullScreenSession` a series uses — which also matches
  *"se pasa la página"* better than replacing the home would.
- [x] 4.3 `home_route_test.dart` (or a sibling) walks to **both** screens from a
  seeded `DayLog`, takes each action, and asserts where it lands. This is the
  gate that would have caught `pack.puzzles.first`.
- [x] 4.4 A test that `4.13` does not appear twice in one day and that `4.12`
  does.

## 5. Evidence

- [x] 5.1 Tier 1 — `flutter analyze --fatal-infos` and `flutter test`, counts
  stated.
- [x] 5.2 Tier 1b — falsification per PROC-5 (commit first, then mutate; red is
  the runner's exit status) over `streakStateFor`, `hoursLeftToday` and
  `brokenRunLength`.
  One survivor, recorded: shifting `atRiskFrom` from 18 to 17 leaves the suite
  green. That is the constant being a product decision bracketed by two clock
  times rather than restated by a test — 15:00 steady against 20:14 at risk. A
  shift to 15 or to 21 is red.
- [x] 5.3 Tier 2 — both screens on the iPhone 17 simulator, reached by seeding
  the log rather than by rooting `main.dart` at them:
  `integration_test/streak_notice_tour_test.dart`, two cases, green. Looking at
  them found two defects no suite had:
  - **`fullScreenSession` carried no `SafeArea`**, so Aki sat under the Dynamic
    Island. Six screens go through that route and all six carried their own;
    the seventh forgot. Now the route insets and the six inner ones are no-ops.
  - **`CenteredStateView` was top-aligned** where the design's body is
    `justify-content:center`, leaving a short state with its headline near the
    status bar over a hand's depth of empty cream.

  One drift left and it is not this change's: the flame and the arrow render as
  the stand-in characters `▲` and `→`. Every glyph in the app does —
  `f0-brand-icons` owns transcribing all fourteen, and it is unblocked now that
  the design digests are reachable.
