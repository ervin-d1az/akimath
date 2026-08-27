# puzzle-completion Specification

## Purpose
What a player sees when a puzzle is finished: that finishing is an event rather than a
board going quiet, which puzzle it was, and the two figures the device can measure on its own.
The board does not stay behind it, and the state carries no hue, because there is no second
outcome to tell it apart from.

## Requirements

### Requirement: req-a-solved-puzzle-is-acknowledged · Finishing is an event

Solving a puzzle SHALL show a screen before returning to the home.

#### Scenario: A board is completed

- **WHEN** the last cell makes a board correct
- **THEN** a completion screen appears, because the alternative — the screen simply going away
  — reads as the app losing the player's place rather than as them having finished
  → `app/test/features/home/ui/home_route_test.dart`

#### Scenario: A sopa de letras is completed

- **WHEN** the last word is claimed
- **THEN** the same screen appears, because finishing is finishing whatever the format
  → `app/test/features/home/ui/home_route_test.dart`

#### Scenario: Leaving an unfinished puzzle shows nothing

- **WHEN** a player closes a puzzle they have not solved
- **THEN** no completion screen appears
  → `app/test/features/home/ui/home_route_test.dart`

### Requirement: req-it-names-what-was-finished · A player knows which puzzle they beat

The screen SHALL name the format that was completed.

#### Scenario: The format is named

- **WHEN** a Kakuro is solved
- **THEN** the screen says so, because five formats are reachable from one home and "you
  finished a puzzle" does not tell a player which
  → `app/test/features/puzzle/ui/puzzle_solved_screen_test.dart`

### Requirement: req-it-shows-only-what-the-device-knows · Two figures, both local

The screen SHALL show the time taken and the streak, and no figure a server could later
contradict.

#### Scenario: Time and streak

- **WHEN** the screen is shown
- **THEN** it carries those two and nothing else — no rating, no accuracy, no comparison with a
  previous attempt
  → `app/test/features/puzzle/ui/puzzle_solved_screen_test.dart`

#### Scenario: The time is the session's

- **WHEN** a puzzle is opened and solved
- **THEN** the time shown is measured from opening it, by the route's clock rather than by a
  clock inside either screen
  → `app/test/features/home/ui/home_route_test.dart`

### Requirement: req-the-board-is-not-behind-it · Finishing ends the session

The completion screen SHALL replace the puzzle rather than sit on top of it.

#### Scenario: Leaving goes home

- **WHEN** a player leaves the completion screen
- **THEN** they arrive at the home, not back at a board they have already finished
  → `app/test/features/home/ui/home_route_test.dart`

### Requirement: req-one-state-carries-no-hue · There is nothing to distinguish

The screen SHALL have a single state.

#### Scenario: No verdict mark

- **WHEN** the screen is drawn
- **THEN** it carries no `VerdictRing` and no success/error colouring, because a puzzle has no
  wrong ending to tell this one apart from — BRD-1 asks that a *pair* be distinguishable by
  shape, and there is no pair
  → `app/test/features/puzzle/ui/puzzle_solved_screen_test.dart`
