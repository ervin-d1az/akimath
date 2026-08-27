## ADDED Requirements

### Requirement: req-board-run-clues · A run says what it must total, where it starts

The board SHALL show each run's sum on the run's first cell, marked with the run's direction.

#### Scenario: A row run and a column run starting on the same cell

- **WHEN** a cell begins both
- **THEN** both clues appear on it, distinguishable by direction, because a cell that showed one of
  them would hide a constraint the player needs
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

#### Scenario: A run whose first cell is not preceded by a blocked cell

- **WHEN** a run starts at the board's edge
- **THEN** its clue still appears, because a Kakuro's clues do not always have a blocked cell to
  live in
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

#### Scenario: A board with no runs

- **WHEN** a caged board is drawn
- **THEN** no clue is shown and the cage labels are unaffected
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`
