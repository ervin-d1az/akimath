## Purpose

Which requests the API answers, what it answers with, and how that surface is held to the
frozen contract.

## ADDED Requirements

### Requirement: req-router-matches-path-templates · A path parameter is part of the path

The router SHALL match a request path against a template, so a segment declared as a parameter
matches any single non-empty segment.

#### Scenario: A concrete id matches its template

- **WHEN** `GET /packs/2f1c9b0e-0000-4000-8000-000000000000` arrives and the table holds
  `GET /packs/{packId}`
- **THEN** it matches that operation, because a contract with a path parameter that only ever
  matched the literal text `{packId}` would route nothing
  → `packages/server/test/routing.test.ts`

#### Scenario: A parameter matches one segment, not several

- **WHEN** `GET /packs/a/b` arrives
- **THEN** it matches nothing, because `{packId}` is one segment and swallowing the rest would
  route requests the contract never described
  → `packages/server/test/routing.test.ts`

#### Scenario: An empty segment is not a parameter

- **WHEN** `GET /packs/` arrives
- **THEN** it matches nothing, because an empty id is a malformed request rather than a pack
  → `packages/server/test/routing.test.ts`

### Requirement: req-contracted-operations-answer-401 · A contracted operation says what is true

Every operation in the frozen contract SHALL be routed, and until authentication exists each
SHALL answer `401` with the frozen error shape.

#### Scenario: A contracted operation with no session

- **WHEN** any of the eight contracted operations is requested
- **THEN** the response is `401`, because the contract declares `401 — No valid session` on all
  of them and there is no session mechanism at all, so it is the true answer rather than a
  placeholder
  → `packages/server/test/routing.test.ts`

#### Scenario: It is not a 404

- **WHEN** `GET /me` is requested
- **THEN** the response is not `404`, because the contract defines `404` as *no such resource*
  and `/me` is a resource that exists and is unbuilt — a client cannot act on the two the same
  way
  → `packages/server/test/routing.test.ts`

### Requirement: req-method-and-path-are-distinguishable · A wrong method is not a wrong path

The router SHALL answer `405` for a known path requested with a method it does not route, and
`404` only when no template matches the path at all.

#### Scenario: A known path, an unrouted method

- **WHEN** `DELETE /health` is requested
- **THEN** the response is `405`, not `404`, because the two are different faults and a client
  retrying the correct method needs to be able to tell
  → `packages/server/test/routing.test.ts`

#### Scenario: No such path

- **WHEN** `GET /nonsense` is requested
- **THEN** the response is `404`
  → `packages/server/test/routing.test.ts`

### Requirement: req-every-error-body-validates · Every error the router emits is on-contract

Every non-2xx body the router produces SHALL carry both `error` and `message`, and SHALL
validate against the frozen `Error` schema.

#### Scenario: Every reachable error status

- **WHEN** each error the router can produce is generated
- **THEN** every body parses against the frozen `Error` schema, because today's
  `{ error: "not_found" }` omits the required `message` and so the one error the server can
  emit is already off-contract
  → `packages/server/test/routing.test.ts`

#### Scenario: The message is not the tag repeated

- **WHEN** an error body is produced
- **THEN** its `message` is prose distinct from its `error` tag, because a message that restates
  the tag tells a client nothing the tag did not
  → `packages/server/test/routing.test.ts`

### Requirement: req-route-table-matches-the-contract · The surface is held to the contract

A gate SHALL compare the route table to `contract/openapi.json` in both directions and report a
count.

#### Scenario: Every contracted operation is routed

- **WHEN** the gate runs
- **THEN** an operation in the contract that the table does not route fails it
  → `packages/server/test/contract-parity.test.ts`

#### Scenario: Every routed operation is contracted

- **WHEN** the gate runs
- **THEN** a route the contract does not describe fails it, unless it is named in the ops
  allowlist — `GET /health` is the one entry, excused by name rather than by a wildcard, because
  a wildcard would excuse the next one silently
  → `packages/server/test/contract-parity.test.ts`

#### Scenario: The gate reports what it checked

- **WHEN** the gate runs
- **THEN** it prints the number of contracted operations compared and fails at zero, because a
  gate that finds no operations would otherwise pass by finding nothing
  → `packages/server/test/contract-parity.test.ts`

## MODIFIED Requirements

### Requirement: req-openapi-declares-405 · The contract declares the transport error it can return

The emitted contract SHALL declare `405` alongside the existing shared error responses.

#### Scenario: 405 on every operation

- **WHEN** the contract is emitted
- **THEN** every operation declares `405`, additively, so `oasdiff` reports no breaking change
  and the router cannot return a status the contract does not describe
  → `packages/contract/test/openapi.test.ts`
