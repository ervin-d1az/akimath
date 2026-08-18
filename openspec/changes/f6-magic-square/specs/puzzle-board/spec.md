## MODIFIED Requirements

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
