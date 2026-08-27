# player-identity Specification

## Purpose
What ties a device-minted player to the account that linked it.

## Requirements

### Requirement: req-a-player-has-an-account · There is no unlinked player on the server

`players` SHALL record the account that linked the row, and SHALL NOT accept a row without one.

#### Scenario: A row with no account

- **WHEN** a player is inserted with no `auth_user_id`
- **THEN** the database refuses it — ADR 0002 leaves no unlinked player on the server at all
  → `packages/server/test/players.test.ts`

#### Scenario: Two players, one account

- **WHEN** a second player is inserted against an account that already has one
- **THEN** the database refuses it, because `Me` carries a single `playerId` and two rows is a
  response the frozen contract cannot express
  → `packages/server/test/players.test.ts`

### Requirement: req-the-account-is-the-sessions · The body cannot choose whose player this is

The account SHALL come from the verified session and SHALL NOT be settable by the request body.

#### Scenario: The body does not offer it

- **WHEN** the committed contract's body for `POST /players/link` is read
- **THEN** it carries neither `authUserId` as required nor as optional — a body naming the account
  it attaches to is an account-takeover with extra steps
  → `packages/server/test/link-request.test.ts`

#### Scenario: The exclusion is readable

- **WHEN** a column is excluded from the "must be in the body" gate
- **THEN** it names where it comes from instead, and it is a column the schema actually requires —
  so a stale exclusion cannot silently excuse nothing
  → `packages/server/test/link-request.test.ts`

### Requirement: req-no-key-into-the-managed-schema · Their schema is theirs

No constraint in `public` SHALL reference the provider's `neon_auth` schema.

#### Scenario: The sweep

- **WHEN** every foreign key in `public` is enumerated
- **THEN** each one points inside `public` — `neon_auth` migrates on the provider's schedule, and a
  constraint of ours is a reason their migration cannot run
  → `packages/server/test/players.test.ts`
