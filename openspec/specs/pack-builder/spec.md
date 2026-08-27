# pack-builder Specification

## Purpose
How an offline pack is produced: what it may be assembled from, why the same
inputs must always yield the same bytes, and what the builder must refuse to
write rather than hand a player content nobody can read or grade.

## Requirements

### Requirement: req-builder-sources · A pack is assembled from sources, not generated wholesale

The builder SHALL assemble a pack from an ordered list of sources, where a source is either a
template invocation or an authored item, and SHALL treat both as first-class rather than treating
authored content as a migration step.

#### Scenario: A pack mixes generated and authored items

- **WHEN** a build declares both template invocations and authored items
- **THEN** the emitted pack contains every item from both, and the frozen validator accepts it
  → `packages/core/test/pack/build.test.ts`

#### Scenario: Only one template family exists

- **WHEN** the builder runs against the template registry as it stands
- **THEN** the emitted pack still carries all six stimulus families, because the authored items
  supply the five the registry cannot yet generate — a pack built from templates alone would offer
  a player one kind of question where the app already draws six
  → `packages/core/test/pack/build.test.ts`

#### Scenario: A template is added later

- **WHEN** a template for a family that is currently authored is added to the registry
- **THEN** replacing those authored items with template invocations changes the build's declaration
  and nothing else, because both are sources
  → `packages/core/test/pack/build.test.ts`

### Requirement: req-builder-deterministic · The same inputs produce the same bytes

The builder SHALL be a pure function of its declared inputs. It SHALL NOT read a clock, draw a
random number, or consult the environment, and the seed base and pack salt SHALL be arguments.

#### Scenario: The builder runs twice

- **WHEN** the builder runs twice over an unchanged declaration
- **THEN** it produces byte-identical output both times
  → `packages/core/test/pack/build.test.ts`

#### Scenario: The seed base changes

- **WHEN** two builds differ only in their seed base
- **THEN** the generated items differ, so the seed is demonstrably doing the work rather than being
  accepted and ignored
  → `packages/core/test/pack/build.test.ts`

#### Scenario: The builder is inspected for ambient input

- **WHEN** the builder's pure modules are walked
- **THEN** no call to a clock, a random source or the environment appears in any of them, checked
  the way `determinism.test.ts` already walks the rest of the package
  → `packages/core/test/determinism.test.ts`

### Requirement: req-builder-refuses-invalid · A pack the validator would reject is never written

The builder SHALL validate every pack against the frozen format before writing it, and SHALL exit
non-zero without writing when validation fails.

#### Scenario: An assembled pack violates the frozen format

- **WHEN** a declaration produces an item the frozen validator rejects
- **THEN** the builder reports the rejection tag and writes no file, so a pack that cannot be read
  is never committed
  → `packages/core/test/pack/build.test.ts`

#### Scenario: A partially written file

- **WHEN** the builder fails for any reason
- **THEN** any previously emitted pack is left exactly as it was, because output is written to a
  temporary path and moved into place only after it has passed
  → `packages/core/test/pack/build.test.ts`

### Requirement: req-builder-answers-are-digests · An answer travels as a digest

The builder SHALL carry every answer as an HMAC digest over the pack salt, and SHALL emit no
plaintext answer anywhere in the pack.

#### Scenario: The emitted pack is swept for plaintext answers

- **WHEN** every string in the emitted pack is walked
- **THEN** no item's canonical answer appears in it, and the sweep reports how many items it checked
  so a walker that visits nothing cannot pass
  → `packages/core/test/pack/build.test.ts`

#### Scenario: An answer that is not storage-canonical

- **WHEN** an authored item declares an answer the canonicaliser does not accept in stored form
- **THEN** the build fails naming that item, because a digest over a non-canonical answer would
  grade a right answer wrong on a device with nothing reporting an error
  → `packages/core/test/pack/build.test.ts`

### Requirement: req-builder-preserves-authored-content · Lifting an authored item changes nothing a player sees

The builder SHALL carry an authored item's stimulus and answer into the frozen envelope unchanged,
adding only the fields the envelope requires.

#### Scenario: An authored item is lifted

- **WHEN** an authored item is placed in the frozen envelope
- **THEN** its stimulus payload is byte-identical to what was authored, and only `skill_id`,
  `keypad`, the digest answer and `diagnosis` are added
  → `packages/core/test/pack/lift.test.ts`

#### Scenario: The whole authored set is lifted

- **WHEN** every authored item the app ships today is lifted
- **THEN** all of them are accepted by the frozen validator, across all six stimulus families, and
  the test reports the count so a lift that silently drops items cannot pass
  → `packages/core/test/pack/lift.test.ts`

### Requirement: req-builder-artifact-committed · The emitted pack is committed and gated

The system SHALL commit the emitted pack and SHALL fail continuous integration when a fresh emission
differs from the committed one.

#### Scenario: The pack is regenerated and the committed copy is not

- **WHEN** the builder's inputs change without the committed pack being regenerated
- **THEN** the build fails, with the artifact staged before it is compared so a pack that was never
  committed at all is caught as well
  → `.github/workflows/ci.yml`, job `core`
