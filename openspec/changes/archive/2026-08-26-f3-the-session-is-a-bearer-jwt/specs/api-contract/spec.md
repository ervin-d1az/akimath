## Purpose

What a caller attaches to prove it has a session, and where that is written down.

## ADDED Requirements

### Requirement: req-one-way-to-authenticate · The contract names the credential

The document SHALL declare exactly one security scheme, and it SHALL be a bearer JWT.

#### Scenario: The scheme is named and described

- **WHEN** the emitted document's `components.securitySchemes` is read
- **THEN** it holds exactly one entry, `session`, of type `http`, scheme `bearer`, format `JWT`,
  described as a Neon Auth access token
  → `packages/contract/test/openapi.test.ts`

### Requirement: req-secure-by-default · An operation cannot be left open by omission

The requirement SHALL be declared once at the document root rather than repeated per operation.

#### Scenario: Declared at the root

- **WHEN** the document's top-level `security` is read
- **THEN** it requires the `session` scheme
  → `packages/contract/test/openapi.test.ts`

#### Scenario: Nothing overrides it

- **WHEN** the document is swept for an operation carrying its own `security`
- **THEN** none does — an unauthenticated operation has to be written deliberately, and `/health`
  is outside this document entirely rather than excused inside it
  → `packages/contract/test/openapi.test.ts`

### Requirement: req-the-router-refuses-what-the-contract-secures · The two artifacts agree about who may knock

`route()` SHALL refuse, without a credential, every operation the contract secures.

#### Scenario: Every secured operation

- **WHEN** each secured operation is routed with no credential
- **THEN** the answer is 401
  → `packages/server/test/contract-parity.test.ts`

#### Scenario: The route the contract does not describe

- **WHEN** the one ops route is requested
- **THEN** it is absent from the contract and answers 200 — a probe carries no session, and
  "everything is 401" would satisfy the scenario above while being a server nobody can reach
  → `packages/server/test/contract-parity.test.ts`
