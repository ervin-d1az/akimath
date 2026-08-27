## Purpose

How a puzzle board draws its three levels of structure.

## ADDED Requirements

### Requirement: req-weight-belongs-to-the-object · Only the board gets the thick outline

The heaviest stroke on a board SHALL be the board's own frame.

#### Scenario: The board is framed

- **WHEN** a board is drawn
- **THEN** it carries a 3 px ink border and a hard shadow, because it is the object and the
  levels inside it step down from something
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

#### Scenario: A cage is not

- **WHEN** a cage boundary is drawn
- **THEN** it is pink, not ink — a cage drawn in the board's own treatment reads as a second
  object stacked on the first
  → `app/test/design/painting/cage_edge_painter_test.dart`

### Requirement: req-inside-the-hierarchy-is-colour-and-stroke · Not thickness

Inside the frame, the levels SHALL differ by colour and stroke rather than by weight.

#### Scenario: Cells are hairlines

- **WHEN** the grid is drawn
- **THEN** each cell's line is thinner than the cage's, which is thinner than the board's
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

#### Scenario: A cage is dashed

- **WHEN** a cage boundary is drawn
- **THEN** it is dashed, which is the third channel the digest names alongside weight and colour
  → `app/test/design/painting/cage_edge_painter_test.dart`

#### Scenario: Only the boundary is drawn

- **WHEN** a cell sits inside its cage with every neighbour in the same cage
- **THEN** nothing is drawn around it, because a cage is a union of cells and a line through its
  middle is not a boundary
  → `app/test/design/painting/cage_edge_painter_test.dart`
