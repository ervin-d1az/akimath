## ADDED Requirements

### Requirement: req-an-item-response-names-one-source · An item is addressed the same way in both directions

An item response SHALL be able to address an item in every way an attempt submission can, SHALL
carry exactly one of those spellings, and SHALL require neither in the schema.

#### Scenario: A pack item can be named

- **WHEN** the item response schema is inspected
- **THEN** it carries `packRef` as `(packId, index)`, because the only items this server has to
  offer are pack items — `POST /packs` issues eighty authored items whose manifest entries are
  digests, and an `itemId` resolves against `issued_items`, which nothing writes
  → `packages/contract/test/openapi.test.ts`

#### Scenario: Neither spelling is required

- **WHEN** the item response's required set is read
- **THEN** it is the prompt and the keypad alone, because a required `itemId` is a field the server
  could not fill for a pack item and inventing one that resolves to nothing is worse than omitting
  it — the same reading that already shapes `Verdict`
  → `packages/contract/test/openapi.test.ts`

#### Scenario: The two shapes cannot drift apart

- **WHEN** the emitted document's item response and attempt submission are compared
- **THEN** every addressing property on the response is an addressing property on the submission,
  and the comparison reports both counts so a sweep that finds nothing cannot pass — an item that
  can be handed out and not answered is the defect this closes
  → `packages/contract/test/openapi.test.ts`

#### Scenario: The rule the schema cannot state

- **WHEN** the `GET /items/next` operation is read
- **THEN** its description says exactly one of the two spellings is present, the way
  `POST /attempts` already does, because `ARCHITECTURE.md` §2 forbids `oneOf` and a rule that lives
  only in a code comment is a rule a caller never sees
  → `packages/contract/test/openapi.test.ts`

#### Scenario: The response stays closed

- **WHEN** the item response schema is inspected
- **THEN** `additionalProperties` is `false`, so a server cannot widen the addressing vocabulary by
  emitting a field the document does not describe
  → `packages/contract/test/openapi.test.ts`

## MODIFIED Requirements

### Requirement: req-spec-no-answer-on-the-wire · The answer never travels and the prompt travels rendered

The system SHALL describe no request or response carrying a template identifier, a template version
or a seed, and SHALL describe no field offering the learner a set of answers to choose from.

#### Scenario: The item response is enumerated

- **WHEN** the item response schema is inspected
- **THEN** it carries the item identifier, the pack reference, the rendered prompt and the keypad,
  and **nothing else** — no `options`, and no template identifier, template version or seed. The
  enumeration is widened by name rather than relaxed: `packRef` is `(packId, index)`, which
  addresses an item and reconstructs no problem. This scenario owns the property set only; which of
  them is required is `req-an-item-response-names-one-source`
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

#### Scenario: A response field stops being guaranteed

- **WHEN** a response property that was required becomes optional
- **THEN** the comparison reports a breaking change and the build fails, because a required
  response property is a promise every client may read without checking, and withdrawing it breaks
  them exactly as removing it would — adding the property beside it is the additive half and does
  not excuse the other
  → `.github/workflows/ci.yml`, job `contract`

#### Scenario: A compatible addition

- **WHEN** an optional field is added to a response
- **THEN** the comparison reports no breaking change and the build passes, so the gate does not
  punish ordinary growth
  → `.github/workflows/ci.yml`, job `contract`
