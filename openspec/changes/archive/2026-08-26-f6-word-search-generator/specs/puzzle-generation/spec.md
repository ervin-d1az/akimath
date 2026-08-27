## Purpose

How a letter grid is produced away from the device.

## ADDED Requirements

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
