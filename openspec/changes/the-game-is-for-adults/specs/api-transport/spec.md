## Purpose

What the endpoints answer, and what they refuse before touching the database.

## MODIFIED Requirements

### Requirement: req-refused-before-the-database · A bad band is a 400, never a 500

A request the database would refuse SHALL be refused by the pure reader first,
before any connection is borrowed.

Narrowing the band set does not make this vacuous — it gives the rule more to catch, not less. Two
values that were accepted yesterday are refusals today, and the reader is the only thing standing
between a hand-crafted request and a constraint violation.

#### Scenario: A band the CHECK would refuse

- **WHEN** `ageBand` is anything other than the one the contract names
- **THEN** it is refused 400 by the pure reader, before any connection is
  borrowed — a constraint violation would have been a stack trace
  → `packages/server/test/link-player.test.ts`

#### Scenario: A band that used to be legal

- **WHEN** `ageBand` is `under_13` or `13_17`
- **THEN** it is refused 400 the same as any other unknown value — a device on an older build is
  the likeliest source of one, and it gets an answer it can read rather than a 500
  → `packages/server/test/link.test.ts`

#### Scenario: A playerId that only stringifies to a uuid

- **WHEN** `playerId` is an array or an object whose `toString` is a uuid
- **THEN** it is refused — `RegExp.test` coerces, so the `typeof` guard is
  load-bearing and mutation testing is what said so
  → `packages/server/test/link.test.ts`
