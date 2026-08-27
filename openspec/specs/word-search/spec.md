# word-search Specification

## Purpose
What a letter grid shows, how a player claims a word in it, and when the puzzle
is finished.

## Requirements

### Requirement: req-words-found-in-eight-directions · A word reads any way it is written

The system SHALL find a word running in any of the eight directions — along, back, down, up and both
diagonals each way.

#### Scenario: Each direction in turn

- **WHEN** a word is placed running in one of the eight directions
- **THEN** it is found, because a grid accepting only the directions its author happened to use
  would refuse a correct answer
  → `app/test/features/puzzle/policy/word_search_test.dart`

#### Scenario: A word that is not there

- **WHEN** a word appears in no direction
- **THEN** it is not found, rather than matching a near miss
  → `app/test/features/puzzle/policy/word_search_test.dart`

#### Scenario: A word that runs off the edge

- **WHEN** a word would continue past the grid
- **THEN** it is not found there, rather than wrapping or reading a shorter prefix
  → `app/test/features/puzzle/policy/word_search_test.dart`

### Requirement: req-words-claimed-by-a-line · A player claims a word by tracing it

A claim SHALL be a straight line of cells, and SHALL be accepted only when those cells spell a word
still to be found.

#### Scenario: A correct trace

- **WHEN** a player traces the cells of an unfound word
- **THEN** it is marked found, in either direction it was traced
  → `app/test/features/puzzle/policy/word_search_test.dart`

#### Scenario: A trace that is not a straight line

- **WHEN** the traced cells bend
- **THEN** nothing is claimed, because a word here is a line by definition
  → `app/test/features/puzzle/policy/word_search_test.dart`

#### Scenario: A word claimed twice

- **WHEN** an already-found word is traced again
- **THEN** the puzzle is unchanged
  → `app/test/features/puzzle/policy/word_search_test.dart`

### Requirement: req-words-done-when-all-are-found · Finished means every word

The puzzle SHALL report itself solved only when every word in its list has been found.

#### Scenario: The last word

- **WHEN** the final unfound word is claimed
- **THEN** the puzzle is solved
  → `app/test/features/puzzle/policy/word_search_test.dart`

#### Scenario: Some still missing

- **WHEN** any word remains
- **THEN** it is not solved, however many have been found
  → `app/test/features/puzzle/policy/word_search_test.dart`

### Requirement: req-words-list-shows-progress · The list says what is left

The screen SHALL show every word and SHALL mark those found, distinguishably **without relying on
hue**.

#### Scenario: A word is found

- **WHEN** a word has been claimed
- **THEN** it is marked by more than colour, so the difference survives deuteranopia
  → `app/test/features/puzzle/ui/word_search_screen_test.dart`

#### Scenario: Nothing is typed here

- **WHEN** the screen is drawn
- **THEN** no keypad appears, because this puzzle takes no digits
  → `app/test/features/puzzle/ui/word_search_screen_test.dart`
