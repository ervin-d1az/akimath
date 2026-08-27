## Why

Word Search is the fifth frozen format and the only one that shares nothing with
the board the other four sit on: a rectangle of letters, a list of words, no
solution grid, no cages, and no digits — so no keypad at all. It is closer to a
second kind of puzzle than a fifth variation of one, and building it finishes F6.

It is also the format whose rejection row a reader *can* see. `word_not_found`
is a scan of a small grid, not a search for a solution, so this kind needs no
exception in the parity gate — which is worth demonstrating exactly once, to
show the exception Kakuro earned was about solving and not about convenience.

## What Changes

- **Word Search**: a letter grid, a word list, and words claimed by tracing a
  line of cells.
- **Eight directions**, matching the frozen validator — backwards and both
  diagonals included, since a grid that accepted only the directions its author
  happened to use would refuse a correct answer.
- **The reader refuses a word its grid does not contain**, because that word can
  never be claimed and the puzzle can never be finished.
- **No keypad on this screen.** Nothing is typed.

## Capabilities

### New Capabilities

- `word-search`: what a letter grid shows, how a word is claimed, and when the
  puzzle is done.

### Modified Capabilities

- `puzzle-content`: the reader gains the fifth and last frozen kind.

## Impact

- `app/lib/features/puzzle/` (a screen of its own), `app/lib/content/model/`,
  one authored grid.
- No new dependency, no change to any frozen format.
