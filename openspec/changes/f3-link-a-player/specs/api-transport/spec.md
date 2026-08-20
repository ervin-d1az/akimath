## Purpose

How a device-minted player becomes a row under an account.

## ADDED Requirements

### Requirement: req-the-account-is-the-tokens · The body may not choose whose player this is

The account SHALL come from the verified session, and a body naming one SHALL be
refused.

#### Scenario: A body that mentions the account

- **WHEN** the request carries `authUserId`
- **THEN** it is refused 400 and nothing is written — the account-takeover the
  frozen schema's `additionalProperties: false` exists to prevent
  → `packages/server/test/link.test.ts`,
  `packages/server/test/link-player.test.ts`

#### Scenario: The row that gets written

- **WHEN** a link succeeds
- **THEN** `auth_user_id` is the token's subject
  → `packages/server/test/link-player.test.ts`

### Requirement: req-link-is-idempotent · Asked twice, answered the same

Repeating a link SHALL produce the same answer and no second row, and a request
without the header the contract marks required SHALL be refused.

#### Scenario: The same account, the same player

- **WHEN** the same link is made twice
- **THEN** both answer 200 with the same profile and exactly one row exists —
  real idempotency, because the inputs determine the row, rather than a replayed
  response
  → `packages/server/test/link-player.test.ts`

#### Scenario: No Idempotency-Key

- **WHEN** the header the contract marks required is absent
- **THEN** the request is refused 400 and nothing is written
  → `packages/server/test/link-player.test.ts`

### Requirement: req-two-conflicts-two-sentences · A second link is refused for the reason it failed

A link that cannot happen SHALL answer 409 and SHALL say which of the two
reasons applies.

#### Scenario: The account already has a player

- **WHEN** an account that has one links a different player
- **THEN** it is 409, saying so
  → `packages/server/test/link-player.test.ts`

#### Scenario: The player already belongs to someone

- **WHEN** a player already under another account is linked
- **THEN** it is 409, saying *that* instead — a device hands its `player_id` on
  when a backup is restored, so the two are different problems
  → `packages/server/test/link-player.test.ts`

#### Scenario: The rows disagree

- **WHEN** the account's player and the player's account do not match each other
- **THEN** it is a conflict rather than an idempotent success — the database's
  constraints make it unreachable, and the policy is not the place to assume so
  → `packages/server/test/link.test.ts`

### Requirement: req-refused-before-the-database · A bad band is a 400, never a 500

A request the database would refuse SHALL be refused by the pure reader first,
before any connection is borrowed.

#### Scenario: A band the CHECK would refuse

- **WHEN** `ageBand` is outside the three
- **THEN** it is refused 400 by the pure reader, before any connection is
  borrowed — a constraint violation would have been a stack trace
  → `packages/server/test/link-player.test.ts`

#### Scenario: A playerId that only stringifies to a uuid

- **WHEN** `playerId` is an array or an object whose `toString` is a uuid
- **THEN** it is refused — `RegExp.test` coerces, so the `typeof` guard is
  load-bearing and mutation testing is what said so
  → `packages/server/test/link.test.ts`
