## Purpose

How a magic square is produced away from the device.

## ADDED Requirements

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
