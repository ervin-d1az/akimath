## Purpose

How a caged board is produced away from the device, and what makes one fit to ship.

## ADDED Requirements

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
