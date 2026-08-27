# puzzle-generation Specification

## Purpose
How a caged board is produced away from the device, and what makes one fit to ship.

## Requirements

### Requirement: req-generation-is-seeded · The same seed is the same board

Generation SHALL be a pure function of its seed and parameters.

#### Scenario: A seed reproduces its board

- **WHEN** the same seed and size are generated twice
- **THEN** the two boards are identical, because a batch that cannot be reproduced cannot be
  reviewed, diffed or regenerated after an edit
  → `packages/core/test/puzzles/caged.test.ts`

#### Scenario: Different seeds differ

- **WHEN** a run of seeds is generated
- **THEN** the boards are not all the same, because a generator that ignored its seed would
  satisfy the requirement above and produce one board forever
  → `packages/core/test/puzzles/caged.test.ts`

#### Scenario: No ambient randomness or clock

- **WHEN** the generator's module graph is inspected
- **THEN** it reaches no `Math.random` and no `Date`, the same bar the rederivation machine
  already meets
  → `packages/core/test/determinism.test.ts`

### Requirement: req-the-square-is-latin · Rows and columns hold each digit once

A generated board's solution SHALL be a Latin square of its size.

#### Scenario: Every row and column is a permutation

- **WHEN** a board is generated at any supported size
- **THEN** each row and each column holds every digit from 1 to the size exactly once
  → `packages/core/test/puzzles/latin.test.ts`

#### Scenario: The square is not always the same one

- **WHEN** boards are generated across a run of seeds
- **THEN** more than one distinct square appears, because a cyclic square used unshuffled would
  make every KenKen in the pack the same puzzle wearing different cages
  → `packages/core/test/puzzles/latin.test.ts`

### Requirement: req-cages-partition-the-board · Every cell is in exactly one cage

A cage partition SHALL cover every cell exactly once, and each cage SHALL be orthogonally
connected.

#### Scenario: A partition covers the board

- **WHEN** a partition is produced for any supported size
- **THEN** every cell appears in exactly one cage
  → `packages/core/test/puzzles/cages.test.ts`

#### Scenario: A cage is one connected shape

- **WHEN** a cage holds more than one cell
- **THEN** its cells form a single orthogonally connected group, because a cage drawn in two
  pieces cannot be outlined and would read as two cages sharing a number
  → `packages/core/test/puzzles/cages.test.ts`

### Requirement: req-the-frozen-validator-decides · Nothing ships that the contract refuses

Every emitted board SHALL be accepted by `parsePuzzle`, and a rejected candidate SHALL be
discarded rather than repaired.

#### Scenario: Every board in a batch is accepted

- **WHEN** a batch is generated
- **THEN** `parsePuzzle` accepts each envelope, because that is the same function the pack
  builder and the device's reader answer to
  → `packages/core/test/puzzles/caged.test.ts`

#### Scenario: A board with more than one solution is discarded

- **WHEN** a candidate is not uniquely solvable
- **THEN** it is refused and the next seed is tried, rather than adjusted until it passes
  → `packages/core/test/puzzles/caged.test.ts`

#### Scenario: The generator holds no second opinion

- **WHEN** the generator's source is inspected
- **THEN** it implements no solver and no uniqueness rule of its own, because a second
  implementation of "solvable" is free to disagree with the one that ships
  → `packages/core/test/puzzles/caged.test.ts`

### Requirement: req-the-batch-reports-what-it-spent · A quiet failure is not a small batch

Generation SHALL report how many candidates it tried, how many it kept, and why the rest were
refused.

#### Scenario: A batch that finds nothing says so

- **WHEN** no candidate is accepted within the attempt budget
- **THEN** the result names the budget and the rejection tags seen, rather than returning an
  empty list that reads as "there was nothing to make"
  → `packages/core/test/puzzles/caged.test.ts`

#### Scenario: The attempt budget is bounded

- **WHEN** a request cannot be satisfied
- **THEN** generation stops after a fixed number of attempts rather than searching forever
  → `packages/core/test/puzzles/caged.test.ts`

### Requirement: req-a-grid-hides-what-it-lists · Every listed word is findable, once

A generated grid SHALL contain each word it lists exactly once.

#### Scenario: Each word appears

- **WHEN** a grid is generated
- **THEN** every word on its list reads somewhere in one of the eight directions
  → `packages/core/test/puzzles/word-search.test.ts`

#### Scenario: And appears only once

- **WHEN** a filler letter completes a second copy of a listed word
- **THEN** the candidate is discarded, because two placements make two different traces correct
  and the puzzle stops having an answer — a rejection the contract already names
  → `packages/core/test/puzzles/word-search.test.ts`

### Requirement: req-the-grid-is-used · A grid is woven, not striped

Placement SHALL use the whole grid and more than one direction.

#### Scenario: An 8×8 hides eight words

- **WHEN** eight words are offered for an 8×8
- **THEN** almost every seed places all eight and none places fewer than seven, because a
  generator that started in one corner would place two or three and every "each word appears
  once" assertion would still pass — those only check the words it claims
  → `packages/core/test/puzzles/word-search.test.ts`

#### Scenario: More than one direction is used

- **WHEN** grids are generated across a run of seeds
- **THEN** words run in more than two of the eight directions, because a grid of left-to-right
  words is a word list with padding
  → `packages/core/test/puzzles/word-search.test.ts`

#### Scenario: A word as long as the grid is wide still fits

- **WHEN** a word is exactly the grid's width
- **THEN** it is placed rather than dropped
  → `packages/core/test/puzzles/word-search.test.ts`

### Requirement: req-the-vocabulary-is-the-callers · Words are content

The generator SHALL take its vocabulary as an argument and hold no word list.

#### Scenario: An empty vocabulary

- **WHEN** no words are offered
- **THEN** nothing is generated, and the batch names the reason rather than returning an empty
  list that reads as "there was nothing to make"
  → `packages/core/test/puzzles/word-search.test.ts`

#### Scenario: A vocabulary too long for the grid

- **WHEN** every word is longer than the grid
- **THEN** the batch exhausts its budget and reports `no_word_fits_the_grid`, distinct from a
  tag the contract raised
  → `packages/core/test/puzzles/word-search.test.ts`

### Requirement: req-the-square-is-true-by-construction · The sums are not searched for

A generated square SHALL hold each number from 1 to size² exactly once, and each line's target
SHALL be that line's total.

#### Scenario: Every number once

- **WHEN** a square is generated at any offered size
- **THEN** its cells are a permutation of 1..size², because distinctness is the format's rule
  and a permutation satisfies it without anything having to search
  → `packages/core/test/puzzles/magic-square.test.ts`

#### Scenario: Every target is its line's total

- **WHEN** a square is generated
- **THEN** each row and column target equals what that line adds up to
  → `packages/core/test/puzzles/magic-square.test.ts`

### Requirement: req-it-prints-enough-to-be-verifiable · The printed cells are measured

How much of the board is printed SHALL scale with its size.

#### Scenario: A small square gives little away

- **WHEN** a 3×3 is generated
- **THEN** it prints at most a third of its cells, because the fraction a 4×4 needs would give
  away most of a 3×3
  → `packages/core/test/puzzles/magic-square.test.ts`

#### Scenario: A larger one prints more, and the reason is not difficulty

- **WHEN** a 4×4 or 5×5 is generated
- **THEN** it prints more than a third, because below that the contract refuses it as
  `search_budget_exhausted` rather than as `solution_not_unique` — the boards are not worse,
  they are unverifiable, and a board whose uniqueness nobody can confirm is one a player may not
  be able to finish
  → `packages/core/test/puzzles/magic-square.test.ts`

#### Scenario: Never the whole board

- **WHEN** any square is generated
- **THEN** at least one cell is left to fill
  → `packages/core/test/puzzles/magic-square.test.ts`

### Requirement: req-an-unverifiable-size-is-refused-up-front · Do not spend a budget on a certainty

A size whose uniqueness the frozen validator cannot decide SHALL be refused before any candidate
is built.

#### Scenario: Six

- **WHEN** a 6×6 is requested
- **THEN** it is refused by name, because 36 distinct values over 36 cells outrun the contract's
  search budget every time — measured at zero accepted out of sixty — and attempting it would
  spend the whole attempt budget on boards the contract was always going to refuse
  → `packages/core/test/puzzles/magic-square.test.ts`

#### Scenario: The batch says which reason

- **WHEN** a batch is asked for an unverifiable size
- **THEN** its report names that reason rather than a contract rejection tag
  → `packages/core/test/puzzles/magic-square.test.ts`

### Requirement: req-the-clues-are-read-off-the-fill · The arithmetic cannot be wrong

Every run's clue SHALL be the total of the cells it covers, and no run SHALL repeat a digit.

#### Scenario: A clue is its run's total

- **WHEN** a board is generated at any supported size
- **THEN** each run's sum equals what its cells hold
  → `packages/core/test/puzzles/kakuro.test.ts`

#### Scenario: No digit twice in a run

- **WHEN** a board is generated
- **THEN** every run's digits are distinct — the format's rule, and what the fill exists to
  satisfy
  → `packages/core/test/puzzles/kakuro.test.ts`

### Requirement: req-runs-cross · Coverage is not a partition

Every cell a player may fill SHALL belong to at least one run, and some SHALL belong to two.

#### Scenario: Every open cell is covered

- **WHEN** a board is generated
- **THEN** each open cell is in a run, because a cell in none can never be deduced
  → `packages/core/test/puzzles/kakuro.test.ts`

#### Scenario: Runs actually cross

- **WHEN** a board is generated
- **THEN** some cell is in two runs — a board whose runs never crossed would be a row of
  unrelated sums rather than a Kakuro
  → `packages/core/test/puzzles/kakuro.test.ts`

#### Scenario: An isolated cell is refused by name, before the fill

- **WHEN** the blocked pattern leaves a cell whose runs are both a single cell
- **THEN** the candidate is refused as `a_cell_belongs_to_no_run`, distinct from a solver
  rejection: one means the pattern was unlucky, the other that the board had more than one answer
  → `packages/core/test/puzzles/kakuro.test.ts`

### Requirement: req-an-unfillable-board-is-refused · The guard is reachable

A board no fill can satisfy SHALL be refused rather than searched for indefinitely.

#### Scenario: A run longer than the digit ceiling

- **WHEN** a run holds more cells than there are digits
- **THEN** it is refused before the search, because discovering it by backtracking costs `9!`
  dead ends — enough to time a test out
  → `packages/core/test/puzzles/kakuro.test.ts`

#### Scenario: And an ordinary board still fills

- **WHEN** a satisfiable board is offered
- **THEN** it fills — without this the scenario above passes for a function that always refuses
  → `packages/core/test/puzzles/kakuro.test.ts`
