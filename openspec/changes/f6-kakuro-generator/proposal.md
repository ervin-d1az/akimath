# Generate Kakuro, and finish the set

## Why

Four of the five formats have generators; Kakuro is the last one hand-authored at a single
board. With this, every format the app draws can be produced in batches and the pack stops being
limited by how many boards somebody was willing to type.

## What changes

- A **pure, seeded Kakuro generator**, judged by the same `parsePuzzle` the other four answer to.
- It blocks cells, fills the rest so every run holds distinct digits, and reads each clue off the
  fill — so the **arithmetic is true by construction** and only uniqueness is in doubt.
- The structural refusal Kakuro alone has is **named**: a cell whose runs are both length one
  belongs to no run at all, and the contract calls that `cage_coverage_incomplete`.

## Out of scope

Putting the boards in the pack. That is a content change, the way the other three generators
left theirs.
