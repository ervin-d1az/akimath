## Purpose

How the server decides who is asking, before it decides what to answer.

## ADDED Requirements

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
