## Purpose

Which board a player is offered, out of everything the pack carries.

## ADDED Requirements

### Requirement: req-one-card-per-format · A format is offered once

The home SHALL offer one puzzle per kind the pack carries, however many boards of that kind it
holds.

#### Scenario: Two boards of one kind

- **WHEN** the pack carries three KenKens
- **THEN** one `KenKen` card appears, because two cards with the same name are two cards a
  player cannot choose between
  → `app/test/features/home/policy/puzzle_of_day_test.dart`

#### Scenario: The order is the pack's

- **WHEN** the kinds are listed
- **THEN** they appear in the order their first board appears in the pack, because which format
  a player meets first is a content decision and the pack is where content decisions are made
  → `app/test/features/home/policy/puzzle_of_day_test.dart`

### Requirement: req-the-board-turns-over-daily · A day is the unit

Which board of a kind is offered SHALL be a pure function of the day.

#### Scenario: The same board all day

- **WHEN** the same day is asked twice
- **THEN** the same board comes back, so leaving a puzzle and returning continues it rather
  than replacing it
  → `app/test/features/home/policy/puzzle_of_day_test.dart`

#### Scenario: Consecutive days rotate

- **WHEN** a kind holds three boards and three consecutive days are asked
- **THEN** all three boards appear, because a rotation that repeated would leave content in the
  pack a player never reaches
  → `app/test/features/home/policy/puzzle_of_day_test.dart`

#### Scenario: One board is always that board

- **WHEN** a kind holds a single board
- **THEN** it is offered every day
  → `app/test/features/home/policy/puzzle_of_day_test.dart`

#### Scenario: A day is a calendar day, not twenty-four hours

- **WHEN** the day spans a daylight-saving transition
- **THEN** the day still advances by exactly one, because component arithmetic and not
  `Duration` is what makes a 23-hour day still a day
  → `app/test/features/home/policy/puzzle_of_day_test.dart`

### Requirement: req-every-board-is-reachable · Nothing in the pack is unreachable

Every board the pack carries SHALL be offered on some day.

#### Scenario: The shipped pack, over a fortnight

- **WHEN** the shipped pack is asked for a fortnight of days
- **THEN** every board it carries has been offered at least once, and the count is reported
  → `app/test/content/pack_variety_test.dart`
