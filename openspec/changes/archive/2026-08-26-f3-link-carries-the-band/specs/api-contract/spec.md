## Purpose

What the frozen API contract must say for the endpoints to be writable at all.

## ADDED Requirements

### Requirement: req-the-link-request-can-create-the-row · A request that creates a row carries what the row needs

`POST /players/link` SHALL require every column of `players` that the database will not supply.

#### Scenario: A column the database will not fill in

- **WHEN** `players` is inspected for columns that are `NOT NULL`, have no default, are not
  generated and are not an identity
- **THEN** each one has a matching required property in the committed contract's request body for
  `POST /players/link` — the `INSERT` is unwritable otherwise
  → `packages/server/test/link-request.test.ts`

#### Scenario: A band the database would refuse

- **WHEN** each band the link request offers is inserted into `players`
- **THEN** the row is accepted — names agreeing is not enough if the value sets do not
  → `packages/server/test/link-request.test.ts`

#### Scenario: One band set, not two

- **WHEN** the emitted document is swept for enums naming a band
- **THEN** exactly two are found — the link request and the profile — and they hold the same
  values in the same order
  → `packages/contract/test/openapi.test.ts`

### Requirement: req-a-breaking-change-can-be-approved · The gate can be answered, not only obeyed

A breaking contract change SHALL fail CI unless a human labelled the pull request.

#### Scenario: Unlabelled

- **WHEN** the emitted document breaks a client and no label is present on the pull request
- **THEN** the job fails and names the label that would approve it
  → `.github/workflows/ci.yml`

#### Scenario: Labelled

- **WHEN** the pull request carries `allow-breaking-contract`
- **THEN** the job passes, having reported what breaks
  → `.github/workflows/ci.yml`

#### Scenario: The base commit is not in the clone

- **WHEN** the checkout is too shallow to hold the commit being compared against
- **THEN** the job fails and says so, rather than reporting the contract as new — the failure that
  had kept this gate from ever running
  → `.github/workflows/ci.yml`
