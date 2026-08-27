# offline-content Specification

## Purpose
The client decides offline whether an answer is right, and it must decide it the way the server
would. One rule, two implementations, one frozen fixture they both answer to.

## Requirements

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
- **WHEN** a pack is read whose item stores an answer that is not canonical
- **THEN** parsing throws rather than serving it, and the shipped pack is checked
  the same way through the real bundle
  → `app/test/content/model/pack_test.dart`, `app/test/content/pack_reader_test.dart`

### Requirement: req-offline-pack-play · The app plays from a bundled pack, with no network

The system SHALL load its items from a pack compiled into the app, and SHALL make no network request
to do so.

#### Scenario: A pack is read from the bundle
- **WHEN** the reader is given a pack via a fake `AssetBundle`
- **THEN** it yields the declared item count with each item's prompt payload, answer and
  `ladder_step`
  → `app/test/content/pack_reader_test.dart`

#### Scenario: Difficulty comes from the pack, never from the client
- **WHEN** an item is read
- **THEN** its difficulty is the pack's `ladder_step` and no rating is computed in Dart
  → `app/test/content/model/pack_test.dart`

#### Scenario: An expired pack is refused
- **WHEN** a pack whose expiry has passed is read with an injected `now`
- **THEN** it reports expired rather than serving its items, and the round is not shown
  → `app/test/content/model/pack_test.dart`, `app/test/features/round/ui/round_route_test.dart`

#### Scenario: A malformed pack fails where it is read
- **WHEN** a pack has no items, an unknown prompt token kind, or an answer that is not
  storage-canonical
- **THEN** parsing throws rather than returning a partial pack
  → `app/test/content/model/pack_test.dart`

#### Scenario: The pack that ships is valid
- **WHEN** the bundled pack is loaded through the real bundle
- **THEN** it parses, is unexpired, and every item has a unique id
  → `app/test/content/pack_reader_test.dart`
