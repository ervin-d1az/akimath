## MODIFIED Requirements

### Requirement: req-puzzle-words-must-be-present · A word that is not in the grid is refused

The reader SHALL refuse a word search whose list names a word its grid does not contain.

#### Scenario: A word that cannot be found

- **WHEN** a word appears in none of the eight directions
- **THEN** the puzzle is refused where the pack is read, because that word can never be claimed and
  the board can never be finished
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: This kind needs no exception

- **WHEN** the parity gate runs
- **THEN** word search is required to refuse its rejection row like the others, because
  `word_not_found` is a scan of a small grid and not a search for a solution
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: Every frozen kind is readable

- **WHEN** the gate reports its coverage
- **THEN** it reports five kinds readable and none pending
  → `app/test/content/model/puzzle_fixture_test.dart`
