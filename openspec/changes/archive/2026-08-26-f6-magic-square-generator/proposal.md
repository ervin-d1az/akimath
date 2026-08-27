# Generate magic squares

## Why

Four of the five formats now have several boards; the magic square and Kakuro are still one
board each, hand-authored. The magic square is the one where hand-authoring failed most
memorably: an authored board was refused as `solution_not_unique` because two of its givens did
not break the eightfold symmetry and one was the forced centre. That is not a mistake careful
typing avoids.

## What changes

- A **pure, seeded magic square generator**, judged by the same `parsePuzzle` the other three
  answer to.
- The **arithmetic is true by construction**: a permutation of 1..size² gives distinctness, and
  each line's target is simply what that line adds up to. Only *uniqueness* is in doubt, which
  is the contract's to decide.
- How much of the board is printed **scales with size, and the numbers are measured** rather
  than picked.
- A size the frozen validator cannot decide is **refused up front, by name**, instead of
  spending the attempt budget on boards it was always going to reject.

## Out of scope

Kakuro, the last format without a generator. And putting these boards in the pack — a content
change, the way the caged and word-search generators left theirs.
