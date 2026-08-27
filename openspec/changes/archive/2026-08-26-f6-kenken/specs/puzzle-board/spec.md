## Purpose

What a puzzle grid shows, what a player may put into it, and how it knows it is
finished — the substrate four of the five frozen formats sit on.

## ADDED Requirements

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
