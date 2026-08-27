## Purpose

How a board shows the player which cell they are on.

## ADDED Requirements

### Requirement: req-the-selected-cell-is-visible · The player can see where they are

A selected cell SHALL be drawn unlike every other cell on the board, whatever its cage draws
around it.

#### Scenario: A cell enclosed by its cage

- **WHEN** a cell's cage outlines it on all four sides and the player selects it
- **THEN** it is still visibly selected, because the ring alone was the cage outline's own ink
  and width on the same edges — the reported defect
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

#### Scenario: Unlike everything else on the board

- **WHEN** a cell is selected
- **THEN** its fill differs from an open cell, a given one and a blocked one
  → `app/test/design/widgets/spec/puzzle_cell_visual_test.dart`

#### Scenario: Nothing is highlighted before a choice

- **WHEN** no cell has been selected
- **THEN** no cell is drawn differently from the others
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

### Requirement: req-selection-survives-without-hue · Shape carries it too

The selected cell SHALL remain distinguishable by shape.

#### Scenario: The ring is still drawn, and inset

- **WHEN** a cell is selected
- **THEN** a ring is drawn inside the cell, inset from its edge so it reads as a second line
  beside the cage's rather than merging with it — BRD-1 asks that the state survive without hue,
  not that hue be unused
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

#### Scenario: A cell the player cannot fill is never highlighted

- **WHEN** a given or blocked cell is passed as selected
- **THEN** its fill does not change, because a highlight on something that cannot change is an
  invitation the board has no way to honour
  → `app/test/design/widgets/spec/puzzle_cell_visual_test.dart`
