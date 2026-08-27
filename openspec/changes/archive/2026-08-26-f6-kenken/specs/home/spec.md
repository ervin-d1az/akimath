## ADDED Requirements

### Requirement: req-home-offers-the-puzzle · `PUZZLE DEL DÍA` returns

The home SHALL offer the day's puzzle when the pack carries one, and SHALL show nothing in its place
when the pack carries none.

#### Scenario: The pack carries a puzzle

- **WHEN** the home is drawn for a pack with at least one puzzle
- **THEN** a `PUZZLE DEL DÍA` card offers it, naming the kind rather than only the word "puzzle"
  → `app/test/features/home/ui/home_screen_test.dart`

#### Scenario: The pack carries none

- **WHEN** no puzzle is available
- **THEN** the card is absent rather than disabled, because a card that cannot be opened is a
  promise the screen cannot keep
  → `app/test/features/home/ui/home_screen_test.dart`

#### Scenario: The home still fits

- **WHEN** the home carries the puzzle card at text scale 1.3
- **THEN** nothing overflows
  → `app/test/design/screen_overflow_test.dart`
