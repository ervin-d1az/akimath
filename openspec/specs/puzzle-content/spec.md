# puzzle-content Specification

## Purpose
How much the shipped pack carries, and what it may not carry.

## Requirements

### Requirement: req-a-week-of-every-format · Tomorrow is a different board

The pack SHALL carry enough boards of each format that a week passes before one repeats.

#### Scenario: Seven of each

- **WHEN** the shipped pack's boards are counted by kind
- **THEN** every kind has at least seven, because the rotation offers one per kind per day
  → `app/test/content/pack_variety_test.dart`

#### Scenario: And all of them are reachable

- **WHEN** a fortnight of days is asked for
- **THEN** every board the pack carries has been offered — seven per kind fits, and fifteen
  would not
  → `app/test/content/pack_variety_test.dart`

### Requirement: req-nothing-the-pad-cannot-enter · The contract permits more than the client can play

No board SHALL require a value the keypad cannot produce.

#### Scenario: A magic square above three

- **WHEN** a 4×4 magic square is offered to the pack
- **THEN** it is refused, because it draws from 1 to 16 and the pad has nine keys — a player
  could not enter seven of them
  → `app/test/content/pack_variety_test.dart`

#### Scenario: The rule is named, not only enforced

- **WHEN** a board exceeding the pad's ceiling reaches the pack
- **THEN** a test says so in a sentence, rather than leaving the reader's `FormatException` as
  the only explanation
  → `app/test/content/pack_variety_test.dart`
