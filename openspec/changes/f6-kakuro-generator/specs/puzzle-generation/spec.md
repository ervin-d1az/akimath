## Purpose

How a Kakuro board is produced away from the device.

## ADDED Requirements

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
