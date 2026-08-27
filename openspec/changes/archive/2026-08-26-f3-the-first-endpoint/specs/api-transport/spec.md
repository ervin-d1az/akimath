## Purpose

How a request reaches the database, and what the first endpoint answers.

## ADDED Requirements

### Requirement: req-the-request-path-is-restricted · Handlers never hold the owner's privileges

Every query a handler runs SHALL run as `app_request`, inside a transaction.

#### Scenario: The role applies

- **WHEN** work runs through the seam
- **THEN** `current_user` is `app_request`, and a `DELETE` on `attempts` is refused — the second
  matters because the first alone would pass for a seam that only reported a name
  → `packages/server/test/request-database.test.ts`

#### Scenario: The role does not outlive the work

- **WHEN** the same pooled connection is used afterwards
- **THEN** it is no longer `app_request` — a bare `SET ROLE` would hand the next request whatever
  the previous one left behind
  → `packages/server/test/request-database.test.ts`

#### Scenario: A handler that throws

- **WHEN** work fails after writing
- **THEN** nothing it wrote survives, and the connection returns to the pool anyway
  → `packages/server/test/request-database.test.ts`

### Requirement: req-the-router-dispatches · The surface stays in the router

`route()` SHALL decide whether to answer or which operation should.

#### Scenario: Built and unbuilt

- **WHEN** a verified caller requests an operation
- **THEN** it is dispatched by `operationId` if it is in `IMPLEMENTED_OPERATIONS`, and answered 501
  if it is not
  → `packages/server/test/routing.test.ts`

#### Scenario: Only a verified caller reaches a handler

- **WHEN** the caller is absent or refused
- **THEN** the router answers and dispatches nothing — a dispatch carries a user id that a handler
  will trust
  → `packages/server/test/routing.test.ts`

#### Scenario: The ids are the contract's

- **WHEN** the route table's operation ids are compared to the committed contract
- **THEN** they match — the hand-written Dart client keys off those names (ADR 0001), and before
  this the table was compared on method and path alone
  → `packages/server/test/contract-parity.test.ts`

### Requirement: req-get-me · The player for this session, and no other

`GET /me` SHALL answer the player linked to the caller's account.

#### Scenario: A linked player

- **WHEN** a verified session whose account has a player requests it
- **THEN** it answers 200 with `playerId`, `ageBand` and `createdAt`, the last with milliseconds
  and a `Z` because the frozen pattern requires both
  → `packages/server/test/get-me.test.ts`

#### Scenario: Somebody else's player

- **WHEN** the account has no player but another account does
- **THEN** it answers 404 — the lookup is by account, never by anything the caller sent
  → `packages/server/test/get-me.test.ts`

#### Scenario: No player yet

- **WHEN** the account has no player at all
- **THEN** it answers **404 and not 401**, naming the endpoint that would create one; a 401 would
  send a client with a good session to fetch another, forever
  → `packages/server/test/get-me.test.ts`

#### Scenario: The query fails

- **WHEN** the database refuses the query
- **THEN** the client gets a 500 that describes nothing, and the log gets the reason — a database
  error quotes the SQL it failed on
  → `packages/server/test/get-me.test.ts`

### Requirement: req-a-subject-must-be-an-account-id · A bad subject is a 401, not a 500

A verified token whose `sub` is not a uuid SHALL be refused.

#### Scenario: A subject of the wrong shape

- **WHEN** a correctly-signed, unexpired, correctly-issued token carries a `sub` that is not a uuid
- **THEN** the caller is refused, because `players.auth_user_id` is a `uuid` and the value would
  otherwise reach the database as a syntax error
  → `packages/server/test/session-verifier.test.ts`
