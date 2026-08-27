## MODIFIED Requirements

### Requirement: req-puzzle-reader-answers-to-the-fixtures · The Dart parsers agree with the frozen format

The system SHALL parse each frozen puzzle payload it claims to support, SHALL refuse each rejection
row, and SHALL report how many kinds it reads.

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

#### Scenario: Killer is read

- **WHEN** the frozen Killer golden is parsed
- **THEN** it yields a board and cages carrying targets and no operations
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: Killer's rejection row

- **WHEN** the frozen Killer rejection row is parsed
- **THEN** it is refused
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: A target no arrangement could reach

- **WHEN** a summing cage asks for a total outside the range its cell count and the board's size
  allow
- **THEN** it is refused — a bound in constant time, not a reachability proof, because whether a
  particular target is achievable under the Latin constraint is the builder's to decide and
  re-deriving it on the device is the solving this app does not do
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: The gate reports its coverage

- **WHEN** the parity gate runs
- **THEN** it reports two kinds readable and three pending, so the gap stays visible
  → `app/test/content/model/puzzle_fixture_test.dart`
