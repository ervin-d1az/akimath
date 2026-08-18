## MODIFIED Requirements

### Requirement: req-builder-carries-puzzles · A pack may hold boards, and they are authored

The builder SHALL accept authored puzzles as a source and SHALL emit them into the pack, refusing any
the frozen validator rejects.

#### Scenario: An authored puzzle is carried

- **WHEN** a declaration names a puzzle source
- **THEN** the emitted pack carries those puzzles and the frozen validator accepts it
  → `packages/core/test/pack/build.test.ts`

#### Scenario: A board the validator refuses

- **WHEN** an authored board has a cage that does not cover it, or more than one solution
- **THEN** the build fails naming the rejection, rather than shipping a puzzle nobody can finish or
  everybody can finish twice
  → `packages/core/test/pack/build.test.ts`

#### Scenario: The build reports what it carried

- **WHEN** a build finishes
- **THEN** it reports how many puzzles it emitted and of which kinds, so an empty puzzle list is
  visible rather than assumed
  → `packages/core/test/pack/build.test.ts`
