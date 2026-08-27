## ADDED Requirements

### Requirement: req-an-anonymous-operation-is-named · A public operation is on a list, never inferred

`route()` SHALL dispatch an operation named on a public list without a credential, SHALL refuse
every other contracted operation without one, and SHALL carry no caller into a public handler.

#### Scenario: A public operation with no credential

- **WHEN** a public operation is routed with no `Authorization` header
- **THEN** it dispatches rather than answering 401, because a visitor who cannot open the app has
  no session and the flow exists for exactly that person
  → `packages/server/test/routing.test.ts`

#### Scenario: Everything else still refuses

- **WHEN** any contracted operation not on the list is routed with no credential
- **THEN** the answer is 401, over the whole route table rather than over a sample, so widening the
  door cannot widen it by accident
  → `packages/server/test/routing.test.ts`,
  `packages/server/test/contract-parity.test.ts`

#### Scenario: The list agrees with the contract

- **WHEN** the public list is compared to the operations the document declares with an empty
  security requirement
- **THEN** the two match in both directions and the gate reports a count, the same shape the route
  table is already held to
  → `packages/server/test/contract-parity.test.ts`

#### Scenario: A public handler is handed no caller

- **WHEN** a public operation dispatches
- **THEN** the decision carries no `userId` — a separate variant rather than an optional field,
  because an optional one makes "there is no caller" and "I forgot the caller" the same value in
  the handler that erases a row
  → `packages/server/test/routing.test.ts`

#### Scenario: A credential presented to a public operation

- **WHEN** a public operation is routed with a credential that does not verify
- **THEN** it still dispatches, because the operation does not read one and refusing here would
  make an irrelevant bad header stop an erasure
  → `packages/server/test/routing.test.ts`

### Requirement: req-the-page-is-the-only-origin-that-may-call · Cross-origin access is an allowlist of one

The transport SHALL admit cross-origin requests to the public operations from the published site's
origin alone.

#### Scenario: The site's origin

- **WHEN** the published page calls a public operation
- **THEN** the request is admitted
  → `packages/server/test/deletion-web.test.ts`

#### Scenario: Any other origin

- **WHEN** another origin calls the same operation
- **THEN** it is refused, and the allowlist is a literal rather than a wildcard — a wildcard would
  let any page on the internet spend a token it had somehow obtained
  → `packages/server/test/deletion-web.test.ts`
