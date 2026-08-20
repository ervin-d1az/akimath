# Tasks

## 1. The policy

- [ ] 1.1 `features/home/policy/streak_state.dart` (PURE) — `StreakState`
  (`none`, `steady`, `atRisk`, `broken`), `atRiskFrom`, and `streakStateFor`.
  Test first: the six scenarios in the delta spec, including the day-after-the-
  moment normalisation and the early-morning case.
- [ ] 1.2 `hoursLeftToday` in the same file — a `Duration` to the next local
  midnight, by component arithmetic. Test the 20:14 case, the one-minute-before
  boundary, and a 23-hour day.
- [ ] 1.3 `features/home/policy/broken_run.dart` (PURE) — `brokenRunLength` and
  `dayOfNewRun`. Test that `streakLength` reads 0 where `dayOfNewRun` reads 1,
  so the two quantities are pinned apart by a test and not only by a comment.

## 2. The pieces

- [ ] 2.1 `flame` in `design/icons/spec/brand_glyph.dart`, with the verbatim
  path data. Test that it draws and that the glyph count gate still reports.
- [ ] 2.2 `design/widgets/streak_badge.dart` — yellow, outlined, `shadowButton`,
  flame + numeral + label.
- [ ] 2.3 `design/widgets/before_after_counters.dart` — muted/flat past against
  yellow/raised present, with the arrow between. Test that the past box carries
  **no** shadow, because that contrast is the point and it is the thing a later
  tidy-up would "fix".

## 3. The screens

- [ ] 3.1 `features/states/ui/streak_at_risk_screen.dart` — `CenteredStateView`
  with the badge in `content`, the countdown chip, and both actions.
- [ ] 3.2 `features/states/ui/streak_lost_screen.dart` — the counters in
  `content`, the reassurance card, one action, and **no rating figure**.
- [ ] 3.3 Register both in `test/design/screen_registry.dart` and run
  `screen_overflow_test` at 1.3 before the layout is called done (D8).

## 4. Reachability

- [ ] 4.1 `features/states/data/streak_notice_store.dart` — the once-a-day
  record for `4.13`, same shape as `OnboardingStore`.
- [ ] 4.2 `FirstRunGate` consults the policy: first run, else a due streak
  screen, else the home.
- [ ] 4.3 `home_route_test.dart` (or a sibling) walks to **both** screens from a
  seeded `DayLog`, takes each action, and asserts where it lands. This is the
  gate that would have caught `pack.puzzles.first`.
- [ ] 4.4 A test that `4.13` does not appear twice in one day and that `4.12`
  does.

## 5. Evidence

- [ ] 5.1 Tier 1 — `flutter analyze --fatal-infos` and `flutter test`, counts
  stated.
- [ ] 5.2 Tier 1b — falsification per PROC-5 (commit first, then mutate; red is
  the runner's exit status) over `streakStateFor`, `hoursLeftToday` and
  `brokenRunLength`.
- [ ] 5.3 Tier 2 — both screens on the simulator, reached by seeding the log
  rather than by rooting `main.dart` at them.
