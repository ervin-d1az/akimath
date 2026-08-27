# A puzzle counts as practice

## Why

The streak counts **days practised** — `RoundScreen` records the day on submit, right or
wrong, because "the streak counts days practised" and a wrong answer is still practice.

A puzzle records nothing. `_startPuzzle` wires `onSolved: leave` and no store, so a player
who spends twenty minutes on a Kakuro comes back to a home that says they have not played
today, while five quick items would have earned the day. Five formats became reachable in the
last change, and all five of them are invisible to the one number the home is built around.

That is not a second streak rule waiting to be designed. It is the existing rule applied to
one surface and not the other.

## What changes

- **A puzzle records the day the player first commits something to the board**, the same
  moment a round records it: not on solve, because a puzzle is a longer commitment than an
  item and a player who works on one for half an hour and leaves it unfinished has practised.
- The two puzzle screens have two different commitments, so each reports its own and the
  **route does the recording** — the store stays out of both screens rather than the same IO
  decision appearing twice.
- Coming back from a puzzle **re-reads the log**, so the streak on the home is current without
  a relaunch — exactly what a series already does.

## Out of scope

A completion screen. Solving a puzzle still pops back to the home, and what it should show —
time, streak, no rating — is a screen with its own registry entry, overflow gate and BRD-1
question. Making the streak correct should not wait on it.
