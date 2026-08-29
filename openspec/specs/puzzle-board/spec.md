# puzzle-board Specification

## Purpose
What a puzzle grid shows, what a player may put into it, and how it knows it is
finished — the substrate four of the five frozen formats sit on.

## Requirements

### Requirement: req-board-draws-its-three-kinds-of-cell · Blocked, given and open cells are told apart

The board SHALL distinguish blocked, given and open cells **by shape or fill and not by hue alone**,
and SHALL let a player enter a value only into an open cell.

#### Scenario: A board with all three kinds

- **WHEN** a board carrying blocked and given cells is drawn
- **THEN** each kind is visually distinct without relying on colour, and the count of each matches
  the payload
  → `app/test/features/puzzle/ui/puzzle_board_test.dart`

#### Scenario: A given cell is tapped

- **WHEN** a player taps a cell the puzzle supplied
- **THEN** nothing is selected and no value can replace it, because a given is part of the question
  → `app/test/features/puzzle/ui/puzzle_board_test.dart`

#### Scenario: A blocked cell is tapped

- **WHEN** a player taps a blocked cell
- **THEN** nothing is selected, and the cell never accepts a value
  → `app/test/features/puzzle/ui/puzzle_board_test.dart`

### Requirement: req-board-entry · A digit goes where the player is looking

The board SHALL apply a digit to the selected cell, SHALL allow it to be replaced or cleared, and
SHALL ignore a digit when nothing is selected.

#### Scenario: Entering, replacing and clearing

- **WHEN** a cell is selected and digits are entered
- **THEN** the last digit stands, clearing empties the cell, and the entry is confined to that cell
  → `app/test/features/puzzle/policy/puzzle_entry_test.dart`

#### Scenario: A digit with nothing selected

- **WHEN** a digit is entered before any cell is chosen
- **THEN** the board is unchanged, rather than a value landing somewhere the player was not looking
  → `app/test/features/puzzle/policy/puzzle_entry_test.dart`

#### Scenario: A digit outside the puzzle's domain

- **WHEN** a digit larger than the board's size is entered
- **THEN** it is refused, because no such value can appear in a solution
  → `app/test/features/puzzle/policy/puzzle_entry_test.dart`

### Requirement: req-board-knows-when-it-is-done · Finished means correct, not merely full

The board SHALL report completion only when every open cell matches the solution the puzzle carries,
and SHALL NOT report progress toward it.

#### Scenario: Every cell filled correctly

- **WHEN** the last open cell is filled with its solution value
- **THEN** the puzzle reports itself solved
  → `app/test/features/puzzle/policy/puzzle_entry_test.dart`

#### Scenario: Every cell filled, one of them wrong

- **WHEN** the board is full but a value disagrees with the solution
- **THEN** it is not solved, and the board does not mark which cell is wrong — a grid that flags
  each mistake as it is made is a grid that solves itself
  → `app/test/features/puzzle/policy/puzzle_entry_test.dart`

#### Scenario: A partially filled board

- **WHEN** some open cells are still empty
- **THEN** it is not solved, whatever the filled ones say
  → `app/test/features/puzzle/policy/puzzle_entry_test.dart`

### Requirement: req-board-fits-the-phone · Six by six survives large text

The board SHALL fit the design viewport at every size the format admits, at text scale 1.0 and 1.3.

#### Scenario: The largest board at the largest text

- **WHEN** a 6×6 board with cage labels is drawn at 390×844 with text scaled to 1.3
- **THEN** nothing overflows and every cell keeps a tappable area no smaller than the minimum touch
  target
  → `app/test/design/screen_overflow_test.dart`, `app/test/features/puzzle/ui/puzzle_board_test.dart`

### Requirement: req-board-cage-label · A cage says exactly what it asks

A cage SHALL show its target once, and SHALL show an operation only when the format it came from
carries one.

#### Scenario: A KenKen cage

- **WHEN** a cage carries an operation
- **THEN** the label shows the target and that operation
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

#### Scenario: A Killer cage

- **WHEN** a cage carries a target and no operation
- **THEN** the label shows the target alone, because a `+` there would be a claim the format does
  not make
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

#### Scenario: A single-cell cage

- **WHEN** a cage holds one cell
- **THEN** no operation is shown whatever the format, since there is nothing to combine
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

### Requirement: req-board-pad-offers-what-fits · A key that cannot act is not offered

The pad SHALL present as unavailable every digit larger than the board's size, and SHALL leave those
keys inert.

#### Scenario: A 3×3 board

- **WHEN** the pad is drawn beside a three-square board
- **THEN** 1, 2 and 3 are available and 4 through 9 are visibly not, so a player is not invited to
  press a key that does nothing
  → `app/test/features/puzzle/ui/puzzle_screen_test.dart`

#### Scenario: A 6×6 board

- **WHEN** the board admits six
- **THEN** six keys are available and three are not
  → `app/test/features/puzzle/ui/puzzle_screen_test.dart`

#### Scenario: An unavailable key is pressed

- **WHEN** a digit outside the domain is pressed anyway
- **THEN** nothing is entered, as before — the presentation changed, not the rule
  → `app/test/features/puzzle/ui/puzzle_screen_test.dart`

### Requirement: req-board-domain-is-declared · A board says what a cell may hold

A board SHALL declare the largest value its cells accept, and the entry policy and the pad SHALL
both read it rather than deriving one from the board's size.

#### Scenario: A caged board

- **WHEN** a KenKen or Killer board of size *n* is read
- **THEN** its cells accept 1 to *n*
  → `app/test/features/puzzle/policy/puzzle_entry_test.dart`

#### Scenario: A magic square

- **WHEN** a magic square of size *n* is read
- **THEN** its cells accept 1 to *n²*, because a magic square is made of exactly those numbers —
  and the previous rule would have refused every digit above *n*
  → `app/test/features/puzzle/policy/puzzle_entry_test.dart`

#### Scenario: The pad follows the domain, not the size

- **WHEN** a 3×3 magic square is played
- **THEN** all nine digits are available, where a 3×3 KenKen offers three
  → `app/test/features/puzzle/ui/puzzle_screen_test.dart`

### Requirement: req-board-margin-targets · A line may say what it must total

The board SHALL be able to show a target beside each row and beneath each column.

#### Scenario: A magic square is drawn

- **WHEN** the board carries row and column targets
- **THEN** each is shown once, against its own line, and the grid still fits the design viewport at
  text scale 1.0 and 1.3
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`, `app/test/design/screen_overflow_test.dart`

#### Scenario: A caged board

- **WHEN** the board carries no targets
- **THEN** no margin is drawn and the grid keeps the width it had
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

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
  → `app/test/design/puzzle/cage_edge_painter_test.dart`

### Requirement: req-inside-the-hierarchy-is-colour-and-stroke · Not thickness

Inside the frame, the levels SHALL differ by colour and stroke rather than by weight.

#### Scenario: Cells are hairlines

- **WHEN** the grid is drawn
- **THEN** each cell's line is thinner than the cage's, which is thinner than the board's
  → `app/test/features/puzzle/ui/puzzle_board_view_test.dart`

#### Scenario: A cage is dashed

- **WHEN** a cage boundary is drawn
- **THEN** it is dashed, which is the third channel the digest names alongside weight and colour
  → `app/test/design/puzzle/cage_edge_painter_test.dart`

#### Scenario: Only the boundary is drawn

- **WHEN** a cell sits inside its cage with every neighbour in the same cage
- **THEN** nothing is drawn around it, because a cage is a union of cells and a line through its
  middle is not a boundary
  → `app/test/design/puzzle/cage_edge_painter_test.dart`
