## Purpose

The committed API specification: what version of OpenAPI it is, what shapes it admits, what it must
never contain, and how a change that would break a shipped client is caught before it ships.

## ADDED Requirements

### Requirement: req-spec-emitted · The specification is emitted, never hand-edited

The system SHALL generate the specification from the same schemas the runtime validates against,
SHALL commit the result, and SHALL fail continuous integration when the committed document and a
fresh emission differ.

#### Scenario: The document is regenerated

- **WHEN** the emitter runs twice over an unchanged source tree
- **THEN** it produces byte-identical output both times
  → `packages/contract/test/openapi.test.ts`

#### Scenario: A schema changes and the document does not

- **WHEN** a request or response schema changes without the committed document being regenerated
- **THEN** the build fails, with the emitted artifact staged before it is compared so a document
  that was never committed at all is caught as well
  → `.github/workflows/ci.yml`, job `contract`

#### Scenario: Emitting needs no server and no database

- **WHEN** the emitter runs
- **THEN** it reads no environment variable, opens no socket and starts no framework, so the gate
  cannot go flaky for a reason unrelated to the contract
  → `packages/contract/test/openapi.test.ts`

### Requirement: req-spec-openapi-303 · The document is OpenAPI 3.0.3

The system SHALL emit OpenAPI 3.0.3 and SHALL contain no construct that only a later version admits.

#### Scenario: The version is declared and the dialect matches it

- **WHEN** the emitted document is inspected
- **THEN** it declares 3.0.3, and carries no `$schema`, no `const`, no `examples` array, no
  `exclusiveMinimum` or `exclusiveMaximum` expressed as a number, and no `type` expressed as an
  array — each of which is 2020-12's spelling and not 3.0's
  → `packages/contract/test/openapi.test.ts`

#### Scenario: An optional value that may be absent

- **WHEN** a schema admits null
- **THEN** the document expresses it as 3.0's `nullable: true` rather than as a union with a null
  type
  → `packages/contract/test/openapi.test.ts`

#### Scenario: The conversion is checked without emitting anything

- **WHEN** the down-conversion is given a JSON Schema document containing each later-version
  construct
- **THEN** it returns the 3.0.3 spelling of each, and a construct it does not know how to convert is
  reported rather than passed through silently
  → `packages/contract/test/openapi-downconvert.test.ts`

### Requirement: req-spec-no-polymorphism · No response is polymorphic

The system SHALL emit no `oneOf`, `anyOf`, `allOf` or `discriminator` anywhere in the document, and
SHALL carry variance inside an opaque object instead.

#### Scenario: The whole document is swept for polymorphism

- **WHEN** every node of the emitted document is walked
- **THEN** none of those four keywords appears, and the sweep reports how many nodes it visited so a
  walker that visits nothing cannot pass
  → `packages/contract/test/openapi.test.ts`

#### Scenario: A shape that genuinely varies

- **WHEN** a response carries content whose shape depends on the kind of item
- **THEN** it is typed as an opaque object, the way the frozen pack format already types a stimulus
  payload, rather than as a union the client has to discriminate
  → `packages/contract/test/openapi.test.ts`

### Requirement: req-spec-no-answer-on-the-wire · The answer never travels and the prompt travels rendered

The system SHALL describe no request or response carrying a template identifier, a template version
or a seed, and SHALL describe no field offering the learner a set of answers to choose from.

#### Scenario: The item response is enumerated

- **WHEN** the item response schema is inspected
- **THEN** it carries the item identifier, the rendered prompt and the keypad, and **nothing else** —
  no `options`, and no template identifier, template version or seed
  → `packages/contract/test/openapi.test.ts`

#### Scenario: The whole document is swept for the rederivation key

- **WHEN** every property name in the document is walked
- **THEN** no schema anywhere names a template, a template version or a seed, because those
  reconstruct the problem and reach the client only as a rendered prompt
  → `packages/contract/test/openapi.test.ts`

#### Scenario: A sync submission is enumerated

- **WHEN** the attempt submission schema is inspected
- **THEN** it carries no field asserting whether the answer was correct, because the verdict is the
  server's to recompute and accepting one would make the invariant a matter of trust
  → `packages/contract/test/openapi.test.ts`

### Requirement: req-spec-no-breaking-change · A breaking change to the contract is a red build

The system SHALL compare an emitted specification against the committed one and SHALL fail when the
difference would break an existing client.

#### Scenario: A response field is removed

- **WHEN** a field a client depends on is dropped, or a request gains a required field
- **THEN** the comparison reports a breaking change and the build fails
  → `.github/workflows/ci.yml`, job `contract`

#### Scenario: A compatible addition

- **WHEN** an optional field is added to a response
- **THEN** the comparison reports no breaking change and the build passes, so the gate does not
  punish ordinary growth
  → `.github/workflows/ci.yml`, job `contract`
