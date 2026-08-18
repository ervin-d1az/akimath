## MODIFIED Requirements

### Requirement: req-puzzle-reader-answers-to-the-fixtures · The Dart parsers agree with the frozen format

The system SHALL parse each frozen puzzle payload it claims to support, SHALL refuse each rejection
row, and SHALL report how many kinds it reads.

#### Scenario: Killer is read

- **WHEN** the frozen Killer golden is parsed
- **THEN** it yields a board and cages carrying targets and no operations
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: Killer's rejection row

- **WHEN** the frozen Killer rejection row is parsed
- **THEN** it is refused
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: The gate reports its coverage

- **WHEN** the parity gate runs
- **THEN** it reports two kinds readable and three pending, so the gap stays visible
  → `app/test/content/model/puzzle_fixture_test.dart`
