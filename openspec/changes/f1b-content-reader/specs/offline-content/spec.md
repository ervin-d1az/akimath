## Purpose

The client decides offline whether an answer is right, and it must decide it the way the server
would. One rule, two implementations, one frozen fixture they both answer to.

## ADDED Requirements

### Requirement: req-canon-parity · The Dart canonicaliser agrees with the frozen fixture

The system SHALL canonicalise answers in Dart to the same result the TypeScript implementation
produces, checked against the committed fixture rather than against a copy of it.

#### Scenario: Every golden vector agrees in both modes
- **WHEN** each vector in `contract/fixtures/canon.golden.json` is canonicalised in learner mode and
  in stored mode
- **THEN** the accepted values and the rejection tags match the fixture exactly
  → `app/test/content/model/canon_test.dart`

#### Scenario: A missing fixture fails loudly
- **WHEN** the fixture cannot be read
- **THEN** the test throws rather than skipping, because a silently absent parity check is worse
  than none
  → `app/test/content/model/canon_test.dart`

#### Scenario: A fraction is not reduced
- **WHEN** `2/4` is canonicalised
- **THEN** the result is `2/4`
  → `app/test/content/model/canon_test.dart`

### Requirement: req-grading-canonical · Grading reads both sides through the contract

The system SHALL read a player's answer in learner mode and a stored expected answer in stored mode,
and SHALL treat an unparseable answer as wrong rather than as an error.

#### Scenario: A stored answer that is not canonical never grades correct
- **WHEN** an item's expected answer would have to be normalised to be canonical
- **THEN** no answer grades correct against it
  → `app/test/features/round/policy/grading_test.dart`

#### Scenario: An unparseable answer is wrong
- **WHEN** the player submits `1/0`, `x+1` or a lone minus sign
- **THEN** the verdict is wrong and no error is raised
  → `app/test/features/round/policy/grading_test.dart`

### Requirement: req-shipped-content-canonical · Every shipped item is storage-canonical

The system SHALL fail the build when any bundled item's expected answer is not canonical.

#### Scenario: An item written with a non-canonical answer
- **WHEN** the shipped pack is checked
- **THEN** every expected answer passes stored-mode canonicalisation
  → `app/test/content/model/demo_pack_test.dart`
