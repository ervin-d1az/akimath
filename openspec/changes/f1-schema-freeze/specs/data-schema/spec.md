## Purpose

Defines what the database holds, what may write to it, and what may delete from it — the table set,
the forward-only migration discipline that keeps it honest, the grants that make an attempt
append-only, and the job that expires data on a schedule.

## ADDED Requirements

### Requirement: req-initial-migration · The schema is forward-only, with a committed snapshot

The system SHALL define the database as ordered forward-only SQL migrations applied by a runner that
depends on no ORM, SHALL record every applied file with a checksum, and SHALL fail continuous
integration when the applied schema and the committed snapshot differ.

#### Scenario: The migrations are applied to an empty database

- **WHEN** the runner is pointed at a fresh, empty database and run twice
- **THEN** the first run applies every migration and the second applies none, and a schema-only dump
  of the result matches the committed snapshot byte for byte
  → `packages/server/test/migration.test.ts`, CI job `integration`

#### Scenario: A migration is edited after it shipped

- **WHEN** a file already recorded as applied has its contents changed
- **THEN** the runner refuses to start and names the file, rather than applying a partial schema
  → `packages/server/test/migration.test.ts`

#### Scenario: A migration fails halfway

- **WHEN** a migration file raises an error partway through
- **THEN** nothing from that file remains applied and it is not recorded, so re-running retries it
  from the start
  → `packages/server/test/migration.test.ts`, CI job `integration`

### Requirement: req-player-shape · A player carries a coarse age band and never a name

The system SHALL store an age band on every player as a NOT NULL column restricted to `under_13`,
`13_17` and `adult`, SHALL store no personal name and no date of birth anywhere in the schema, and
SHALL make a player row without a band impossible rather than merely discouraged.

#### Scenario: A player row is written without a band

- **WHEN** a player row is inserted with no age band
- **THEN** the database rejects it, and the same is true of every path that writes a player row
  → `packages/server/test/players.test.ts`, CI job `integration`

#### Scenario: A player row is written with a band nobody decided

- **WHEN** a player row is inserted with a band outside the three permitted values
- **THEN** the database rejects it, so widening the set is a schema change and never a caller's
  choice
  → `packages/server/test/players.test.ts`, CI job `integration`

#### Scenario: The schema is enumerated for personal data

- **WHEN** every column of every table this migration creates is enumerated
- **THEN** no column stores a personal name, and no column stores a day, month or year of birth —
  only the coarse band
  → `packages/server/test/players.test.ts`, CI job `integration`

### Requirement: req-erasure-grants · Only erasure and the retention job may delete an attempt

The system SHALL grant the request-path role SELECT and INSERT on attempts and nothing else, SHALL
grant DELETE on attempts to the retention role alone, and SHALL express both as grants rather than as
discipline.

#### Scenario: The request-path role tries to change history

- **WHEN** the request-path role issues a DELETE or an UPDATE against attempts
- **THEN** the database refuses, and the grant catalogue shows that role holding only SELECT and
  INSERT on that table
  → `packages/server/test/grants.test.ts`, CI job `integration`

#### Scenario: The retention role may delete and nothing more

- **WHEN** the grant catalogue is enumerated for the retention role
- **THEN** it holds DELETE on attempts and on the diagnosis events, and holds no INSERT or UPDATE on
  either
  → `packages/server/test/grants.test.ts`, CI job `integration`

### Requirement: req-retention-job · Retention is a job whose figures live in one pure module

The system SHALL delete attempts older than 400 days and diagnosis events older than 30 days, under
the retention role, from cutoffs computed by a module that reads no clock and holds the only copy of
those two figures.

#### Scenario: The cutoffs are computed from an injected instant

- **WHEN** the cutoff function is called with an instant
- **THEN** it returns that instant minus 400 days for attempts and minus 30 days for diagnosis
  events, from a module that reads no clock, and those are the only two places either figure appears
  in the source
  → `packages/server/test/retention.test.ts`

#### Scenario: The job runs twice over the same data

- **WHEN** the job runs, then runs again with the same injected instant
- **THEN** the second run deletes nothing, both runs report the counts they deleted, and the
  aggregates calibration reads are unchanged by either run
  → `packages/server/test/retention.test.ts`, CI job `integration`

#### Scenario: A cutoff lands on a daylight-saving transition

- **WHEN** the cutoff is computed for an instant whose local calendar day is 23 or 25 hours long
- **THEN** the cutoff is still exactly 400 days earlier, because the figures are absolute elapsed
  time and not a walk over local midnights
  → `packages/server/test/retention.test.ts`

### Requirement: req-pack-manifest · An offline pack is one row, not one row per item

The system SHALL store an issued offline pack as a single manifest row carrying the references needed
to rederive every item in it, SHALL identify an item by its pack and its index within that pack, and
SHALL store no row per offline item.

#### Scenario: A pack of fifty items is issued

- **WHEN** a pack containing fifty items is recorded
- **THEN** exactly one row exists for it, and the fifty items are recoverable from that row alone
  → `packages/server/test/offline-packs.test.ts`, CI job `integration`

#### Scenario: An item is identified after the fact

- **WHEN** an attempt refers to an offline item
- **THEN** it does so by pack and index, and the server can rederive the item from the manifest
  without the client having told it what the item was
  → `packages/server/test/offline-packs.test.ts`, CI job `integration`
