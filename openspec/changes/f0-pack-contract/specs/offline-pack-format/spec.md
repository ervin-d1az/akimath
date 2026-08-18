## Purpose

Defines the offline pack: the versioned, committed artifact a child's device replays with no
network — its items, their stimulus payloads and answer specs, its puzzles, its keypad layout, its
diagnosis payload and its skill-map node states — together with the answer canonicalization both
stacks must agree on, frozen as golden fixtures so TypeScript and Dart cannot drift.

## ADDED Requirements

### Requirement: req-pack-artifact · The offline pack format is a versioned, committed artifact

The system SHALL define the pack format once, in `contract/`, and SHALL fail CI when the emitted
format and the committed artifact differ.

#### Scenario: The format is regenerated and unchanged

- **WHEN** the emitter runs twice
- **THEN** both runs produce byte-identical output and `git diff --exit-code` passes
  → `packages/contract/test/pack_format.test.ts`, CI job `contract`

#### Scenario: The normalised form of every fixture is recorded alongside it

- **WHEN** the emitter runs over `contract/fixtures/`
- **THEN** each fixture has a committed record of the structure the TypeScript parser normalises it
  to, and re-running the emitter leaves those records byte-identical
  → `packages/contract/test/pack_format.test.ts`, CI job `contract`

### Requirement: req-pack-fixtures · A golden fixture exists for every kind the pack can carry

The system SHALL carry one golden fixture per stimulus kind and per puzzle kind, each with its
rejection rows, in `contract/fixtures/`.

#### Scenario: Eleven kinds are fixtured

- **WHEN** `contract/fixtures/` is enumerated
- **THEN** it holds a golden fixture for each of the six stimulus kinds and each of the five puzzle
  kinds, and the TypeScript parser accepts every one
  → `packages/contract/test/fixtures.test.ts`

#### Scenario: A rejection row is rejected

- **WHEN** a fixture containing `""`, `"1/0"`, `"x+1"`, U+0660, U+2212, ZWSP or a combining mark is
  parsed as an answer
- **THEN** the parser rejects it with a stable tag
  → `packages/contract/test/canon.test.ts`

#### Scenario: A malformed board is rejected

- **WHEN** a puzzle fixture declares a cage that does not cover its cells, an impossible sum, or a
  board with no unique solution
- **THEN** the parser rejects it with a stable tag
  → `packages/contract/test/fixtures.test.ts`

### Requirement: req-keypad-layouts · The keypad is one of three named layouts, not a per-template spec

The system SHALL declare `KeypadLayout` as a closed enum of `item`, `puzzle` and `otp`.

#### Scenario: A template cannot request a bespoke keypad

- **WHEN** a pack item declares its keypad
- **THEN** the value is one of the three layouts and no per-key list is accepted
  → `packages/contract/test/keypad_layout.test.ts`

### Requirement: req-diagnosis-slot · The pack carries the error screen's diagnosis in a reserved, nullable slot

The system SHALL carry, per item, a nullable and separately versioned diagnosis payload holding one
entry per labelled distractor keyed by the digest of that distractor's canonical answer, and SHALL
carry one generic fallback per skill for an answer no distractor anticipated. The pack SHALL NOT
carry a correct answer in plaintext.

#### Scenario: A labelled distractor is found by the digest of its canonical answer

- **WHEN** a wrong answer that a fixture labels as a distractor is canonicalized and digested with
  the fixture's pack salt
- **THEN** the lookup yields that distractor's misconception, its steps and its explanation
  → `packages/contract/test/diagnosis.test.ts`

#### Scenario: An unanticipated answer resolves to the skill's fallback

- **WHEN** a wrong answer matching no labelled distractor is looked up
- **THEN** the lookup yields the fallback declared for that item's skill rather than nothing
  → `packages/contract/test/diagnosis.test.ts`

#### Scenario: A skill with items and no fallback is rejected

- **WHEN** a pack carries an item for a skill that declares no generic fallback
- **THEN** the parser rejects the pack with a stable tag
  → `packages/contract/test/diagnosis.test.ts`

#### Scenario: The slot is reserved, so an empty diagnosis still parses

- **WHEN** a pack declares `diagnosis` as null on an item
- **THEN** the parser accepts the pack and reports that item as carrying no diagnosis
  → `packages/contract/test/diagnosis.test.ts`

### Requirement: req-pack-declares-node-state · Skill-map node state travels in the pack and is never derived

The system SHALL carry the state of every skill-map node the pack references, and the client SHALL
have no rule that computes a node's state from anything else.

#### Scenario: Node state is read, not computed

- **WHEN** a pack declaring its skill-map nodes is parsed
- **THEN** every node yields the state the pack declared, with no threshold, count or ratio
  consulted
  → `packages/contract/test/skill_map_state.test.ts`

#### Scenario: A node without a declared state is rejected

- **WHEN** a pack references a skill-map node and declares no state for it
- **THEN** the parser rejects the pack with a stable tag rather than defaulting the node
  → `packages/contract/test/skill_map_state.test.ts`
