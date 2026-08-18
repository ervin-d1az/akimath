## MODIFIED Requirements

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
