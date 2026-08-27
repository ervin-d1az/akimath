# item-diagnosis Specification

## Purpose
What an item carries so a wrong answer can be explained rather than merely
marked: the labelled distractors, the Spanish copy attached to each, and the
things that copy may never say to the person reading it.

## Requirements

### Requirement: req-diagnosis-labelled-distractors · A wrong answer is recognised, not just rejected

An item SHALL be able to carry distractors, each pairing the digest of a specific wrong answer with
copy that explains the misconception behind it.

#### Scenario: A recognised wrong answer

- **WHEN** a learner submits an answer whose digest matches a distractor
- **THEN** that distractor's copy is what explains the mistake, rather than a generic message
  → `packages/core/test/pack/diagnosis.test.ts`

#### Scenario: An unrecognised wrong answer

- **WHEN** a learner submits a wrong answer matching no distractor
- **THEN** the skill's fallback copy explains instead, so no wrong answer is ever met with silence
  → `packages/core/test/pack/diagnosis.test.ts`

#### Scenario: Every skill can answer for itself

- **WHEN** the emitted pack is inspected
- **THEN** every `skill_id` an item declares has both a node and a fallback, because an item whose
  skill has neither is an item the frozen validator refuses
  → `packages/core/test/pack/build.test.ts`

### Requirement: req-diagnosis-distractors-are-distinct · A distractor is a wrong answer, and only one of them

The system SHALL emit no distractor whose digest equals the item's answer, and no two distractors
sharing a digest on the same item.

#### Scenario: A distractor that is actually the answer

- **WHEN** a distractor's digest matches the item's own answer
- **THEN** the pack is refused, because an item that diagnoses the right answer as a mistake is
  worse than one that diagnoses nothing
  → `packages/core/test/pack/diagnosis.test.ts`

#### Scenario: The same wrong answer twice

- **WHEN** two distractors on one item share a digest
- **THEN** the pack is refused, because whichever copy the reader picked, the other was written and
  is never seen
  → `packages/core/test/pack/diagnosis.test.ts`

### Requirement: req-diagnosis-copy-never-names-the-failure · The copy explains, it does not scold

Diagnosis copy SHALL be written in es-MX, SHALL explain the reasoning that leads to the right
answer, and SHALL NOT tell the reader they are wrong, bad, or slow.

#### Scenario: The copy is swept for the words it may not use

- **WHEN** every string of diagnosis copy in the emitted pack is walked
- **THEN** none of them contains "incorrecto", "error", "fallaste", "mal" or "equivocado", the same
  list `verdict_screen.dart` is already held to, and the sweep reports how many strings it checked
  → `packages/core/test/pack/diagnosis.test.ts`

#### Scenario: The copy is in Spanish and not a placeholder

- **WHEN** the emitted copy is inspected
- **THEN** every `explain` and every step is non-empty and none is a placeholder left from
  authoring, because a pack that ships "TODO" to a player has failed quietly
  → `packages/core/test/pack/diagnosis.test.ts`

### Requirement: req-diagnosis-optional-per-item · An item without distractors is still a valid item

An item SHALL be permitted to carry no diagnosis, and the pack SHALL remain valid when it does.

#### Scenario: An item with no distractors

- **WHEN** an item declares no diagnosis
- **THEN** the pack is still accepted, so authoring copy for one family does not block shipping the
  others
  → `packages/core/test/pack/build.test.ts`

#### Scenario: How much of the pack is diagnosed

- **WHEN** the builder finishes
- **THEN** it reports how many items carry distractors and how many do not, so the gap between "the
  format supports it" and "the content exists" is visible rather than assumed
  → `packages/core/test/pack/build.test.ts`
