## Purpose

What the frozen schema records about a player, once the product is for adults only.

## MODIFIED Requirements

### Requirement: req-player-shape · A player carries a coarse age band and never a name

The system SHALL store an age band on every player as a NOT NULL column restricted to `adult`, SHALL
store no personal name and no date of birth anywhere in the schema, and SHALL make a player row
without a band impossible rather than merely discouraged.

The column survives the collapse deliberately. It is the only thing the schema records about who a
player is, and *"we asked and they said adult"* is a different fact from *"we never asked"* — the
second is indistinguishable from never having had a policy. The narrowing is a **forward-only
migration**; `0001_initial.sql` chose a `CHECK` over an enum precisely so that replacing the value
set is one statement.

#### Scenario: A player row is written without a band

- **WHEN** a player row is inserted with no age band
- **THEN** the database rejects it, and the same is true of every path that writes a player row
  → `packages/server/test/players.test.ts`, CI job `integration`

#### Scenario: A player row is written with a band nobody decided

- **WHEN** a player row is inserted with a band outside the one permitted value — `under_13` and
  `13_17` among them, which the database accepted until this change
- **THEN** the database rejects it, so widening the set is a schema change and never a caller's
  choice
  → `packages/server/test/players.test.ts`, CI job `integration`

#### Scenario: The one permitted band is accepted

- **WHEN** `adult` is inserted
- **THEN** the row is accepted, and the sweep reports the counts it compared — a CHECK narrowed to
  one value is exactly where a test can start refusing everything and still look green
  → `packages/server/test/players.test.ts`, CI job `integration`

#### Scenario: The schema is enumerated for personal data

- **WHEN** every column of every table this migration creates is enumerated
- **THEN** no column stores a personal name, and no column stores a day, month or year of birth —
  only the coarse band
  → `packages/server/test/players.test.ts`, CI job `integration`

#### Scenario: The applied file is not edited

- **WHEN** the band set is narrowed
- **THEN** it is a new forward-only migration and `0001_initial.sql` is byte-identical — the runner
  refuses to start when a recorded checksum moves, and the live database has already run that file
  → `packages/server/test/migration.test.ts`, CI job `integration`
