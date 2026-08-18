# Design

## D1 — A third screen, not a reused verdict

| Candidate | Why not |
|---|---|
| `VerdictScreen` | Requires a `Verdict`. Passing `Verdict.correct` puts a solid ring and "¡Bien hecho!" on a screen whose alternative never existed — a puzzle has no wrong ending, only an unfinished one. |
| `SeriesSummaryScreen` | Carries `correct` out of `total`. A puzzle has neither. |

So a third screen, which reuses the parts rather than the shape: `Aki`, `StatTile`,
`BrandButton`, `IconButtonTile`.

## D2 — BRD-1 is satisfied by construction, and that is worth saying

The invariant is that success and error be distinguishable by **shape**, not only hue. This
screen has one state: there is no error to tell it apart from. A `VerdictRing` here would be a
mark with nothing to contrast against.

Stating it, because "no ring" would otherwise read as an omission on a screen that sits beside
two that have one.

## D3 — The route holds the clock

Neither `PuzzleScreen` nor `WordSearchScreen` has a clock. Adding one to both is the same
decision written twice — the objection that put `onPractised` in the route rather than a store
in each screen.

So the route stamps the start when it pushes the puzzle and subtracts when `onSolved` fires. It
already owns `now` and already stamps the day.

**Elapsed is wall-clock from opening the board**, including time spent reading the rules, and
that is not a rounding error — a puzzle is a sitting, not a reaction test. `req-quiet-timing`
says time is measured quietly and shown at the end; it does not say it is a stopwatch.

## D4 — It replaces the puzzle

`pushReplacement`, so leaving goes home rather than back to a finished board. The board would
still be there, still solved, with no way to do anything to it.

## D5 — The streak counts today, appended

The day was recorded the moment the player first committed to the board, so today is in the
store. `_log` may not have been re-read since, so the figure is computed the way `RoundScreen`
computes it: today appended to what the screen holds. The alternative shows a streak one short
of the one the home will show a second later, which is the two-screens-one-morning contradiction
`StreakPolicy` was fixed for.
