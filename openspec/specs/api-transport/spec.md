# api-transport Specification

## Purpose
What listens on the socket, and what it is allowed to change.

## Requirements

### Requirement: req-the-transport-does-not-decide · Policy is not the framework's

The adapter SHALL return the status and body `route()` produced, unaltered.

#### Scenario: Every route the app has

- **WHEN** each contracted operation, the ops route, an unknown path and a wrong method are
  requested through the adapter
- **THEN** each response matches what `route()` returns for the same method and path — a
  transport that reshaped either would put the contract parity gate one layer away from what a
  client receives
  → `packages/server/test/http-server.test.ts`

#### Scenario: A path the framework never registered

- **WHEN** a path no route mentions is requested
- **THEN** the answer is the policy's 404, carrying the `message` the frozen `Error` schema
  requires — not the framework's, which would not
  → `packages/server/test/http-server.test.ts`

#### Scenario: A query string is not part of the path

- **WHEN** a request carries a query string
- **THEN** it is matched on the path alone, or every link with a tracking parameter becomes a
  404
  → `packages/server/test/http-server.test.ts`

### Requirement: req-every-response-is-json · One content type

Every response SHALL be JSON.

#### Scenario: Success and both errors

- **WHEN** health, an unauthenticated operation and an unknown path are requested
- **THEN** each carries `application/json`
  → `packages/server/test/http-server.test.ts`

### Requirement: req-read-the-credential · Absent is not malformed

Reading the `Authorization` header SHALL distinguish nothing offered from something unusable.

#### Scenario: Nothing offered

- **WHEN** the header is missing, empty or only whitespace
- **THEN** the caller is absent, and earns "you need a session"
  → `packages/server/test/session.test.ts`

#### Scenario: Something unusable

- **WHEN** the header names another scheme, carries no token, or carries a token with a space in it
- **THEN** it is malformed and carries a one-line reason — never truncated into a token that was
  never sent
  → `packages/server/test/session.test.ts`

#### Scenario: The scheme's case

- **WHEN** the scheme is spelled `bearer`, `BEARER` or `BeArEr`
- **THEN** it is accepted, because RFC 7235 defines the scheme as case-insensitive
  → `packages/server/test/session.test.ts`

### Requirement: req-verify-the-token · Only a token this project issued

A bearer token SHALL be accepted only if its signature, issuer, expiry, algorithm and subject all
hold.

#### Scenario: A good token

- **WHEN** an unexpired token signed by the key set, from the configured issuer, carrying a `sub`,
  is presented
- **THEN** the caller is a session carrying that subject
  → `packages/server/test/session-verifier.test.ts`

#### Scenario: Each way it can fail

- **WHEN** the token is expired, from another issuer, signed by a key we do not have, carries no
  `sub`, or is not a JWT at all
- **THEN** the caller is refused — never thrown, because an exception here is a 500 for a request
  that deserves a 401
  → `packages/server/test/session-verifier.test.ts`

#### Scenario: A refusal is safe to log

- **WHEN** any refusal reason is produced
- **THEN** it does not contain the token
  → `packages/server/test/session-verifier.test.ts`

### Requirement: req-refuse-to-start-misconfigured · A missing key set is not a 401

The process SHALL refuse to start when it cannot know where the keys are.

#### Scenario: No base URL

- **WHEN** `NEON_AUTH_BASE_URL` is absent, unparseable, or plaintext off loopback
- **THEN** startup fails naming the variable and the value — a server that starts and refuses
  everything reads as "authentication is broken" rather than "a variable is missing"
  → `packages/server/test/auth-config.test.ts`

#### Scenario: One URL, two facts

- **WHEN** the base URL is set
- **THEN** the issuer is its origin and the JWKS URL is `/.well-known/jwks.json` beneath it, unless
  `NEON_AUTH_JWKS_URL` was given, which wins
  → `packages/server/test/auth-config.test.ts`

### Requirement: req-answer-honestly · 501 once the caller has authenticated

An operation that is routed, secured and unwritten SHALL answer 501, and declare it.

#### Scenario: A verified caller

- **WHEN** a verified session requests any contracted operation
- **THEN** the answer is 501 — 401 would be a lie the client retries forever, and 404 denies a path
  the contract names
  → `packages/server/test/routing.test.ts`

#### Scenario: The declaration prunes itself

- **WHEN** the contract's 501 declarations are compared to the operations the router answers 501 for
- **THEN** they are the same set, in both directions, so implementing an endpoint is also what stops
  it advertising itself as missing
  → `packages/server/test/contract-parity.test.ts`

#### Scenario: The probe is unaffected

- **WHEN** `/health` is requested by anyone, credential or not
- **THEN** it answers 200 — a key-server outage must not make the application look dead
  → `packages/server/test/routing.test.ts`

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
