## Purpose

What listens on the socket, and what it is allowed to change.

## ADDED Requirements

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
