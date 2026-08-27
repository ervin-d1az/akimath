## Purpose

How a puzzle reaches a device: what a pack may carry, what the app refuses, and
why no board is ever built on the phone.

## ADDED Requirements

### Requirement: req-puzzle-authored-never-generated · Boards arrive, they are not made here

The system SHALL read puzzles from the pack and SHALL NOT construct or search for one on the device.

#### Scenario: The app is inspected for a solver

- **WHEN** the puzzle feature's sources are walked
- **THEN** nothing generates a board, places a cage or searches for a unique solution — that work is
  the builder's, and a uniqueness search running before a player can start is not something to ship
  → `app/test/architecture/no_puzzle_generation_test.dart`

### Requirement: req-puzzle-reader-answers-to-the-fixtures · The Dart parsers agree with the frozen format

The system SHALL parse each frozen puzzle payload it claims to support, SHALL refuse each rejection
row, and SHALL report how many kinds it reads so an unbuilt kind is visible rather than assumed.

#### Scenario: A golden payload is read

- **WHEN** the frozen golden for a supported kind is parsed
- **THEN** it yields the board, cages and solution the fixture declares
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: A rejection row is read

- **WHEN** the frozen rejection row for a supported kind is parsed
- **THEN** it is refused, so the two stacks cannot disagree about what is a valid board
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: A kind this build cannot draw

- **WHEN** a pack carries a puzzle kind the app has no renderer for
- **THEN** it is refused where the pack is read, not halfway into a board
  → `app/test/content/model/puzzle_fixture_test.dart`

### Requirement: req-puzzle-solution-stays-off-the-screen · The board never draws its own answer

The system SHALL NOT render any value from the solution into a cell the player is expected to fill.

#### Scenario: The rendered board is swept

- **WHEN** a board is drawn from a payload whose solution is known
- **THEN** no open cell shows its solution value before the player enters one, and the sweep reports
  how many cells it checked
  → `app/test/features/puzzle/ui/puzzle_board_test.dart`
