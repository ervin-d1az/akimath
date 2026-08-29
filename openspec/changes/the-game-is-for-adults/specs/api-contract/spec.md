## Purpose

What the frozen API contract must say for the endpoints to be writable at all, and where the band
set is allowed to be written down.

## MODIFIED Requirements

### Requirement: req-the-link-request-can-create-the-row · A request that creates a row carries what the row needs

`POST /players/link` SHALL require every column of `players` that the database will not supply.

`ageBand` stays **required** over a single-valued enum rather than leaving the body. A required
field a caller cannot get wrong looks like dead weight, and it is what keeps the row a record of the
*player's* declaration instead of a record of the server's policy — a column the server fills in
unconditionally is evidence that an `INSERT` ran and nothing more.

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

#### Scenario: The sweep cannot pass over nothing

- **WHEN** the offered band set is read out of the committed contract
- **THEN** it is not empty and the count is reported — with one legal band left, a sweep that
  silently found none would be indistinguishable from one that found and accepted them all
  → `packages/server/test/link-request.test.ts`

#### Scenario: One band set, not two

- **WHEN** the emitted document is swept for enums naming a band
- **THEN** exactly two are found — the link request and the profile — and they hold the same
  values in the same order
  → `packages/contract/test/openapi.test.ts`

## ADDED Requirements

### Requirement: req-the-band-set-has-one-home · Nobody retypes the band set

The set of bands SHALL be declared in `packages/contract` and derived everywhere else, and no file
under `packages/server/src` SHALL restate it.

The comment beside the declaration claimed the set was *"declared once"*. It was declared four times
by hand, and the fourth — the server's own reader — was tied to nothing: no test referenced it, so
it could refuse a band the contract offered, or accept one the `CHECK` would reject at insert time,
which is a 500 where the contract promises a 400. Collapsing the set to one value makes that copy
cheap to miss, which is why this requirement lands before the narrowing rather than after it.

#### Scenario: The server does not keep its own list

- **WHEN** `packages/server/src` is swept for a literal band value
- **THEN** none is found — the reader derives its set from `@akimath/contract`
  → `packages/server/test/link.test.ts`

#### Scenario: The reader and the contract agree

- **WHEN** the set the pure reader accepts is compared to the committed contract's
  `PlayerLink.ageBand` enum
- **THEN** they hold the same values, and the count compared is reported
  → `packages/server/test/link.test.ts`

#### Scenario: The band enum sweep does not key on a value

- **WHEN** the emitted document is swept for band enums
- **THEN** the sweep finds them by where they sit rather than by a member's spelling, and fails at
  zero found — a detector keyed on `under_13` reports a narrowed set as a vanished one
  → `packages/contract/test/openapi.test.ts`
