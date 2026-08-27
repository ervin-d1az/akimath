## ADDED Requirements

### Requirement: req-the-public-operations-are-declared · The two operations a stranger may call are in the contract

The emitted document SHALL declare the deletion-request and deletion-confirmation operations, and
each SHALL state in its own `description` that erasure does not remove the identity.

#### Scenario: Both operations are described

- **WHEN** the emitted document is read
- **THEN** it declares an operation that takes an address and one that takes a confirmation token,
  because the most destructive endpoint in the system is the last one that should be reachable
  without appearing in the document that describes the surface
  → `packages/contract/test/openapi.test.ts`

#### Scenario: The scope is in the contract, not only in the copy

- **WHEN** the confirmation operation's `description` is read
- **THEN** it says the Neon Auth account, the email and the sign-in survive the call, matching
  `deleteMe`'s own wording, so the two doors to one erasure describe it the same way
  → `packages/contract/test/openapi.test.ts`

#### Scenario: Neither takes a body field naming an account

- **WHEN** both request schemas are read
- **THEN** neither admits an account id or a player id, and an unknown property is refused, so a
  caller cannot name whose data this is
  → `packages/contract/test/openapi.test.ts`, `packages/server/test/deletion-web.test.ts`

#### Scenario: The addition is measured against the shipped document

- **WHEN** the contract is re-emitted and the pinned `oasdiff` is run against the base commit
- **THEN** its verdict is recorded in the change rather than assumed — adding a path is additive
  and the gate fails only on a breaking change, and the first per-operation `security` override in
  the document is the one thing that could make it say otherwise
  → CI job `contract`

## MODIFIED Requirements

### Requirement: req-secure-by-default · An operation cannot be left open by omission

The requirement SHALL be declared once at the document root rather than repeated per operation,
and an operation SHALL override it only by appearing on a named list of public operations.

#### Scenario: Declared at the root

- **WHEN** the document's top-level `security` is read
- **THEN** it requires the `session` scheme
  → `packages/contract/test/openapi.test.ts`

#### Scenario: Nothing overrides it

- **WHEN** the document is swept for an operation carrying its own `security`
- **THEN** nothing does except the two deletion operations, each with an empty requirement and each
  named on the list — the deliberate act the previous wording anticipated, rather than a third one
  arriving by omission
  → `packages/contract/test/openapi.test.ts`

#### Scenario: A public operation that is not on the list

- **WHEN** an operation carries `security: []` and is absent from the list
- **THEN** the sweep fails, because the list is a literal and not a predicate: the next public
  operation has to be argued for in the diff
  → `packages/contract/test/openapi.test.ts`

#### Scenario: /health is still outside the document

- **WHEN** the document is read for an ops probe
- **THEN** it holds none — a public *client* operation is described here and an ops route is not,
  which is the distinction the list draws
  → `packages/contract/test/openapi.test.ts`
