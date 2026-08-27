# Design

## D1 — First commitment, not solve

Three candidate triggers:

| Trigger | Says | Problem |
|---|---|---|
| Solve | you finished a puzzle | A puzzle is a longer commitment than an item. Half an hour of real work on an unfinished Kakuro would pay nothing, while five quick items pays a day. |
| Open | you looked at a puzzle | Opening a screen is not practice, and it would let a player farm a streak by tapping a card. |
| **First commitment** | you worked on a puzzle | Matches `RoundScreen`, which records on submit *right or wrong* because the streak counts days practised. |

`RoundScreen`'s own comment settles it: the day is recorded "regardless of what \[the verdict\]
says". A wrong answer is practice; so is an unfinished board.

**Verified, not assumed:** `DayLog.recording` merges into a `Set` of start-of-day values, so
recording the same day repeatedly is idempotent. A player who commits ten cells records one
day, and a player who does a series and then a puzzle records one day. That is what makes
"record early and often" safe rather than a source of double counting.

## D2 — The two formats commit differently, and that is stated rather than incidental

`PuzzleScreen` types digits into cells; `WordSearchScreen` claims words. There is no common
"entry" event, so:

- **A board** commits when a value is entered into a cell.
- **A sopa de letras** commits when a word is *successfully claimed*. A trace that spells
  nothing is the analogue of a gesture that was never submitted, not of a wrong answer — the
  player has not asserted anything about the puzzle.

The asymmetry is a decision, so it lives here. Left to the implementation it would read as an
accident of where the call happened to go.

## D3 — The screens report, the route records

Both screens gain `onPractised`, a `VoidCallback?`. Neither takes a `DayLogStore`.

`RoundScreen` does take one, which makes this an inconsistency worth naming. The reason it
does not follow: there is one round screen and two puzzle screens, so the store in the puzzle
case would be **the same IO decision written twice**, free to diverge the first time one of
them changes. The route already owns `_dayLog` and `_refreshLog`, and already does exactly
this dance around a series.

This is not a refactor of `RoundScreen`. Moving its store out is a change with its own
reasoning and its own tests, and doing it here would hide this one inside it.

## D4 — Re-read on return, do not increment

The route re-reads the log when the puzzle route pops, rather than adding a day to what it
holds. Same reason the series does: the store is the source of truth and the screen holds only
what it last read. Incrementing locally is how a screen ends up showing a figure the store
would not yield — the contradiction `StreakPolicy` was fixed for.
