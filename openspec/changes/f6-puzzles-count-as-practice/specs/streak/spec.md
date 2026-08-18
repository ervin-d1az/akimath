## Purpose

When a day counts as practised, on every surface that can practise.

## ADDED Requirements

### Requirement: req-a-puzzle-records-the-day · Working on a puzzle is practice

The system SHALL record the day when a player first commits something to a puzzle, on every
puzzle format.

#### Scenario: A digit entered on a board

- **WHEN** a player types a value into a cell of any board format
- **THEN** the day is recorded, because the streak counts days practised and a round records on
  submit whether the answer was right or wrong
  → `app/test/features/home/ui/home_route_test.dart`

#### Scenario: A word claimed in a sopa de letras

- **WHEN** a player claims a word
- **THEN** the day is recorded
  → `app/test/features/home/ui/home_route_test.dart`

#### Scenario: Not on solve

- **WHEN** a player works on a puzzle and leaves it unfinished
- **THEN** the day is still recorded, because a puzzle is a longer commitment than an item and
  recording only on solve would pay a player nothing for half an hour of practice
  → `app/test/features/home/ui/home_route_test.dart`

#### Scenario: Not on merely opening one

- **WHEN** a player opens a puzzle and leaves without committing anything
- **THEN** nothing is recorded, because opening a screen is not practice
  → `app/test/features/home/ui/home_route_test.dart`

#### Scenario: A trace that spells nothing is not a commitment

- **WHEN** a player drags across letters that spell no word in the list
- **THEN** nothing is recorded, because that is the word search's analogue of an unfinished
  gesture rather than of a submitted answer
  → `app/test/features/home/ui/home_route_test.dart`

### Requirement: req-the-day-is-recorded-once · Practising twice is one day

Recording SHALL be idempotent per day across surfaces.

#### Scenario: A puzzle after a series, on the same day

- **WHEN** a player finishes a series and then works on a puzzle on the same day
- **THEN** the streak counts one day, not two, because `DayLog` holds days and never moments
  → `app/test/features/home/ui/home_route_test.dart`

### Requirement: req-the-home-re-reads-after-a-puzzle · The number on the home is the number in the store

Returning from a puzzle SHALL re-read the day log rather than reuse what the screen last held.

#### Scenario: The streak rises without a relaunch

- **WHEN** a player with no recorded days works on a puzzle and returns to the home
- **THEN** the home shows a streak of one, because the store is the source of truth and the
  screen holds only what it last read — the same reason a series re-reads
  → `app/test/features/home/ui/home_route_test.dart`

### Requirement: req-the-store-lives-in-one-place · One IO decision, not one per screen

A puzzle screen SHALL report that a commitment happened and SHALL NOT hold a day log store.

#### Scenario: Neither screen takes a store

- **WHEN** the puzzle screens are constructed
- **THEN** neither accepts a `DayLogStore`, because the two formats commit differently and
  putting the store in both would put the same IO decision in two places, free to diverge
  → `app/test/features/puzzle/ui/puzzle_screen_test.dart`,
    `app/test/features/puzzle/ui/word_search_screen_test.dart`
